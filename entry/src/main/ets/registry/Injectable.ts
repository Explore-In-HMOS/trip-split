export default abstract class Injectable {
  // cleanup or lifecycle method
  abstract onDispose?(): void;
}