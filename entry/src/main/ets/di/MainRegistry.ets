import { AppDatabase } from '../database/AppDatabase';
import { Register, ServiceRegistry } from '../registry/ServiceRegistry';
import UIRegistry from '../registry/UIRegistry';

export class MainRegistry extends ServiceRegistry implements UIRegistry {
  context: Context

  private constructor(context: Context) {
    super();
    this.context = context;
  }

  public static build(context: Context): MainRegistry {
    const instance = new MainRegistry(context);
    instance.initialize();
    return instance;
  }

  @Register(AppDatabase)
  public registerAppDatabase(): AppDatabase {
    return new AppDatabase(this.context);
  }
}

