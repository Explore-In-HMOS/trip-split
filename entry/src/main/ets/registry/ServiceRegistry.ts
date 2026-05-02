import type Injectable from './Injectable';

/**
 * Relaxed constructor type that doesn't enforce 'new' to allow private constructors
 * but still captures the class name and target type.
 */
type Constructor<T> = { name: string };

type RegistryWithMethods = ServiceRegistry & Record<string, () => Injectable>;

const eagerServices = new Map<string, string>();
const lazyServices = new Map<string, string>();

let globalRegistry: ServiceRegistry | null = null;

function setGlobalRegistry(registry: ServiceRegistry): void {
  globalRegistry = registry;
}

/**
 * Registers a method as a service factory.
 * Services can be eager (default) or lazy.
 * @param cls The class type to register
 * @param options Registration options (name for multiple instances, lazy for on-demand creation)
 * @returns MethodDecorator
 */
export function Register<T extends Injectable>(
  cls: Constructor<T>,
  options: { name?: string, lazy?: boolean } = {}
): MethodDecorator {
  return function (_target, propertyKey, descriptor) {
    const methodName = propertyKey.toString();
    const name = options.name ?? 'default';
    const key = `${cls.name}::${name}`;
    const isLazy = options.lazy ?? false;

    // Prevent duplicate method registrations
    if (eagerServices.has(methodName) || lazyServices.has(methodName)) {
      throw new Error(`ServiceRegistry: Service factory method '${methodName}' already registered.`);
    }

    // Prevent duplicate service name/type registrations
    const existingEager = Array.from(eagerServices.values());
    const existingLazy = Array.from(lazyServices.values());
    if (existingEager.includes(key) || existingLazy.includes(key)) {
      throw new Error(`ServiceRegistry: Service name '${name}' for '${cls.name}' type is already registered. Use a different name.`);
    }

    if (isLazy) {
      lazyServices.set(methodName, key);
    } else {
      eagerServices.set(methodName, key);
    }

    return descriptor;
  };
}

/**
 * Resolves a registered service from the registry.
 * throws Error if the service is unavailable or the registry isn't ready.
 * @param cls { Constructor }.
 * @param options Resolution options (name for specific instance lookup)
 * @returns PropertyDecorator
 */
export function Resolve<T extends Injectable>(
  cls: Constructor<T>,
  options: { name?: string } = {}
): PropertyDecorator {
  const name = options.name ?? 'default';
  const key = `${cls.name}::${name}`;
  return function (target, propertyKey): void {
    Object.defineProperty(target, propertyKey, {
      configurable: true,
      enumerable: true,
      get: function (this: ServiceRegistry) {
        if (!globalRegistry) {
          throw new Error(`Resolve Error: '${key}' cannot be accessed before ServiceRegistry is ready.`);
        }

        const instance = globalRegistry.get<T>(key);
        Object.defineProperty(this, propertyKey, {
          value: instance,
          writable: true,
          configurable: true,
          enumerable: true
        });

        return instance;
      },
      set: function (this: ServiceRegistry, val: Injectable | undefined) {
        // If it's initializing with undefined, ignore to keep the getter on prototype active
        if (val === undefined) {
          return;
        }

        Object.defineProperty(this, propertyKey, {
          value: val,
          writable: true,
          configurable: true,
          enumerable: true
        });
      }
    });
  };
}

/**
 * Central registry for all service instances and factories.
 */
export class ServiceRegistry {
  private readonly instances = new Map<string, Injectable>();
  private readonly factories = new Map<string, () => Injectable>();
  private readonly creatingInstances = new Set<string>();

  constructor() {
    setGlobalRegistry(this);
  }

  /**
   * Call all @Register methods (loop over eager/lazy service maps)
   */
  protected initialize(): void {
    // Initialize eager services
    for (const [_methodName, className] of eagerServices.entries()) {
      if (!this.instances.has(className)) {
        try {
          this.get(className);
        } catch (e) {
          console.error(`ServiceRegistry: Failed to initialize eager service '${className}':`, e);
        }
      }
    }

    // Register lazy factories
    for (const [methodName, className] of lazyServices.entries()) {
      this.factories.set(className, () => {
        if (this.instances.has(className)) {
          return this.instances.get(className)!;
        }

        const instance = (this as unknown as RegistryWithMethods)[methodName]();
        this.instances.set(className, instance);
        this.factories.delete(className);
        return instance;
      });
    }
  }

  /**
   * Clears all services and disposes of any lifecycle hooks.
   */
  public destroy(): void {
    this.instances.forEach(service => service.onDispose?.());
    this.instances.clear();
    this.factories.clear();
    this.creatingInstances.clear();
  }

  /**
   * Get a service instance by key
   * @param key registration key
   * @returns T an instance of the service
   * @throws Error if circular deps are detected
   */
  public get<T extends Injectable>(key: string): T {
    const instance = this.instances.get(key);
    if (instance) {
      return instance as T;
    }

    if (this.creatingInstances.has(key)) {
      throw new Error(`ServiceRegistry Error: Circular dependency detected while creating service '${key}'.`);
    }

    this.creatingInstances.add(key);

    try {
      const factory = this.factories.get(key);
      if (factory) {
        const created = factory();
        this.instances.set(key, created);
        this.factories.delete(key);
        return created as T;
      }

      // 2. Check in eagerServices or lazyServices to call the method on this registry
      let methodName: string | undefined;
      for (const [mName, kName] of eagerServices.entries()) {
        if (kName === key) {
          methodName = mName;
          break;
        }
      }

      if (!methodName) {
        for (const [mName, kName] of lazyServices.entries()) {
          if (kName === key) {
            methodName = mName;
            break;
          }
        }
      }

      const registryWithMethods = this as unknown as RegistryWithMethods;
      if (methodName && registryWithMethods[methodName]) {
        const created = registryWithMethods[methodName]() as Injectable;
        this.instances.set(key, created);
        return created as T;
      }

      throw new Error(`ServiceRegistry Error: No instance or factory found for '${key}'.`);
    } finally {
      this.creatingInstances.delete(key);
    }
  }
}