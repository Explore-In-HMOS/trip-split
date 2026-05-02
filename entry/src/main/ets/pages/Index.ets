import { TripPage } from './TripPage';
import { ArcSwiper } from '@ohos.arkui.ArcSwiper';
import { OldTripsPage } from './OldTripsPage';

@Entry
@Component
struct Index {
  @Provide pathStack: NavPathStack = new NavPathStack();
  @Provide refreshOldTrips: number = 0;

  build() {
    Navigation(this.pathStack) {
      ArcSwiper() {
        TripPage()
        OldTripsPage()
      }
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .height('100%')
    .width('100%')
  }
}