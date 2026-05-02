import { AppDatabase } from '../database/AppDatabase';
import { Resolve } from '../registry/ServiceRegistry';
import { Trip } from '../model/Trip';
import {
  ArcList,
  ArcListItem,
  LengthMetrics,
  ComponentContent,
  ArcListAttribute,
  ArcListItemAttribute
} from '@kit.ArkUI';

@Builder
function oldTripsHeader() {
  Text('Past Trips')
      .fontColor(Color.White)
      .fontSize('22fp')
      .padding({ top: 10 })
      .fontWeight(FontWeight.Bold)
}

@Builder
export function OldTripsPageBuilder() {
  OldTripsPage();
}

@Component
export struct OldTripsPage {
  @Consume pathStack: NavPathStack;
  @Resolve(AppDatabase)
  private database?: AppDatabase;
  @State trips: Trip[] = [];
  @State isLoading: boolean = true;
  @Watch('onRefreshChanged') @Consume refreshOldTrips: number;

  onRefreshChanged() {
    this.loadTrips();
  }

  context: UIContext = this.getUIContext();
  arcListHeader: ComponentContent<object> = new ComponentContent(
    this.context,
    wrapBuilder(oldTripsHeader)
  );

  async aboutToAppear(): Promise<void> {
    await this.loadTrips();
  }

  private async loadTrips(): Promise<void> {
    if (!this.database) {
      return;
    }
    this.isLoading = true;
    try {
      const all = await this.database.getTrips();
      // Only show finished trips
      this.trips = all.filter(t => t.finishedAt !== null && t.finishedAt !== '');
    } catch (error) {
      console.error(`Failed to load trips: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    ArcList({ header: this.arcListHeader }) {

      // Loading
      if (this.isLoading) {
        ArcListItem() {
          Row() {
            LoadingProgress()
              .color(Color.White)
              .width(24)
              .height(24)
            Text('Loading...')
              .fontColor('#888888')
              .fontSize('14fp')
              .margin({ left: 10 })
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
        }
        .width('414px')
        .height('129px')
        .borderRadius('65px')
        .backgroundColor('#26FFFFFF')
      }

      // Empty state
      if (!this.isLoading && this.trips.length === 0) {
        ArcListItem() {
          Text('No past trips yet')
            .fontColor('#888888')
            .fontSize('14fp')
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .width('414px')
        .height('129px')
        .borderRadius('65px')
        .backgroundColor('#26FFFFFF')
      }

      // Trip rows
      ForEach(this.trips, (trip: Trip) => {
        ArcListItem() {
          Row() {
            Column({ space: 4 }) {
              Text(trip.name)
                .fontSize('16fp')
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(trip.createdAt)
                .fontSize('12fp')
                .fontColor('#888888')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize('20fp')
              .fontColor('#888888')
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .alignItems(VerticalAlign.Center)
        }
        .width('414px')
        .height('129px')
        .borderRadius('65px')
        .backgroundColor('#26FFFFFF')
        .onClick(() => {
          this.pathStack.pushPathByName('TripAnalysisPage', trip);
        })
      }, (trip: Trip) => trip.id.toString())

    }
    .width('100%')
    .height('100%')
    .space(LengthMetrics.px(10))
    .scrollBar(BarState.Off)
  }
}