import {
  ArcButton,
  ArcButtonOptions,
  ArcButtonStyleMode,
  ArcButtonPosition,
  ArcSwiper,
  ArcSwiperController,
  ArcButtonStatus,
  ArcSwiperAttribute,
  ColorMetrics
} from '@kit.ArkUI';
import { AppDatabase } from '../database/AppDatabase';
import { Trip } from '../model/Trip';
import { Resolve } from '../registry/ServiceRegistry';

interface CurrencyInfo {
  code: string;
  symbol: string;
  name: string;
}

const CURRENCIES: CurrencyInfo[] = [
  { code: 'USD', symbol: '$', name: 'US Dollar' },
  { code: 'EUR', symbol: '€', name: 'Euro' },
  { code: 'GBP', symbol: '£', name: 'British Pound' },
  { code: 'JPY', symbol: '¥', name: 'Japanese Yen' },
  { code: 'CNY', symbol: '¥', name: 'Chinese Yuan' },
  { code: 'INR', symbol: '₹', name: 'Indian Rupee' },
  { code: 'TRY', symbol: '₺', name: 'Turkish Lira' }
];

@Builder
export function AddTripPageBuilder() {
  AddTripPage();
}

@Entry
@ComponentV2
struct AddTripPage {
  pathStack: NavPathStack = new NavPathStack();
  private wearableSwiperController: ArcSwiperController = new ArcSwiperController();
  @Resolve(AppDatabase)
  private database?: AppDatabase;
  @Local step: number = 0;
  private readonly maxStep = 2;
  @Local tripName: string = '';
  @Local members: string[] = [];
  @Local newMemberName: string = '';
  @Local selectedCurrency: CurrencyInfo = CURRENCIES[0];
  @Local errorMessage: string = '';
  @Local isSaving: boolean = false;

  private getStepLabel(step: number): string {
    switch (step) {
      case 0:
        return 'next 1/3';
      case 1:
        return 'next 2/3';
      case 2:
        return 'finish';
      default:
        return 'next';
    }
  }

  private showError(msg: string): void {
    this.errorMessage = msg;
    setTimeout(() => {
      this.errorMessage = '';
    }, 2000);
  }

  private hasDuplicateMemberName(name: string): boolean {
    const normalizedName = name.trim().toLocaleLowerCase();
    return this.members.some(member => member.trim().toLocaleLowerCase() === normalizedName);
  }

  private async saveTrip(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;

    try {
      const normalizedTripName = this.tripName.trim();
      if (await this.database?.hasTripWithName(normalizedTripName)) {
        this.showError('Trip name already exists');
        return;
      }

      const createdAt = Date.now().toString();
      const tripId = await this.database?.insertTrip(
        normalizedTripName,
        this.selectedCurrency.symbol,
        createdAt
      );

      if (tripId === undefined || tripId === -1) {
        this.showError('Failed to save trip');
        return;
      }

      const insertPromises = this.members.map(member =>
      this.database?.insertTripPerson(tripId, member)
      );
      await Promise.all(insertPromises);

      const tripInfo: Trip = {
        id: tripId,
        name: this.tripName.trim(),
        currency: this.selectedCurrency.symbol,
        createdAt: createdAt
      };
      this.pathStack.pop(tripInfo);

    } catch (error) {
      this.showError('Something went wrong, please try again');
    } finally {
      this.isSaving = false;
    }
  }

  @Local topOptions: ArcButtonOptions = new ArcButtonOptions({
    label: 'cancel',
    position: ArcButtonPosition.TOP_EDGE,
    styleMode: ArcButtonStyleMode.CUSTOM,
    backgroundColor: ColorMetrics.resourceColor($r('app.color.blue_color')),
    fontColor: ColorMetrics.resourceColor(Color.White),
    onClick: () => {
      if (this.step === 0) {
        this.pathStack.pop();
      } else {
        this.step--;
        this.errorMessage = '';
        this.topOptions.label = this.step === 0 ? 'cancel' : 'previous';
        this.bottomOptions.label = this.getStepLabel(this.step);
        this.wearableSwiperController.showPrevious();
      }
    }
  });
  @Local private bottomOptions: ArcButtonOptions = new ArcButtonOptions({
    label: 'next 1/3',
    position: ArcButtonPosition.BOTTOM_EDGE,
    styleMode: ArcButtonStyleMode.CUSTOM,
    backgroundColor: ColorMetrics.resourceColor($r('app.color.blue_color')),
    fontColor: ColorMetrics.resourceColor(Color.White),
    onClick: () => {
      if (this.step === 0) {
        if (this.tripName.trim().length === 0) {
          this.showError('Please enter a trip name');
          return;
        }
      } else if (this.step === 1) {
        if (this.members.length === 0) {
          this.showError('Add at least one member');
          return;
        }
      }

      if (this.step === this.maxStep) {
        this.saveTrip();
        return;
      }

      this.step++;
      this.errorMessage = '';
      this.topOptions.label = this.step === 0 ? 'cancel' : 'previous';
      this.bottomOptions.label = this.getStepLabel(this.step);
      this.wearableSwiperController.showNext();
    }
  });

  build() {
    NavDestination() {
      Stack() {
        ArcSwiper(this.wearableSwiperController) {

          Column({ space: 8 }) {
            Text('New Trip')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
            Text('Enter a name for\nyour trip')
              .fontSize(12)
              .fontColor('#AAAAAA')
              .textAlign(TextAlign.Center)
            TextInput({ placeholder: 'Trip name', text: this.tripName })
              .onChange((val) => this.tripName = val)
              .width('70%')
              .borderRadius(12)
            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(11)
                .fontColor($r('app.color.red_color'))
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Scroll() {
            Column({ space: 6 }) {
              Text('Members')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .margin({ top: 44 })

              if (this.errorMessage.length > 0) {
                Text(this.errorMessage)
                  .fontSize(11)
                  .fontColor('#FF6B6B')
                  .textAlign(TextAlign.Center)
              }

              if (this.isSaving) {
                Text('Saving...')
                  .fontSize(11)
                  .fontColor('#AAAAAA')
                  .textAlign(TextAlign.Center)
              }

              Row({ space: 6 }) {
                TextInput({ placeholder: 'Name', text: this.newMemberName })
                  .onChange((val) => this.newMemberName = val)
                  .layoutWeight(1)
                  .borderRadius(10)
                  .height(34)
                  .fontSize(12)
                Button('+')
                  .fontWeight(FontWeight.Bold)
                  .width(34)
                  .height(34)
                  .fontSize(18)
                  .backgroundColor($r('app.color.blue_color'))
                  .borderRadius(17)
                  .padding(0)
                  .onClick(() => {
                    const trimmed = this.newMemberName.trim();
                    if (trimmed.length === 0) {
                      return;
                    }
                    if (this.hasDuplicateMemberName(trimmed)) {
                      this.showError('Member name already added');
                      return;
                    }
                    this.members = [...this.members, trimmed];
                    this.newMemberName = '';
                  })
              }
              .width('78%')

              ForEach(this.members, (member: string, index: number) => {
                Row({ space: 6 }) {
                  Text(member)
                    .fontSize(13)
                    .fontColor(Color.White)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Button('-')
                    .fontWeight(FontWeight.Bold)
                    .width(28)
                    .height(28)
                    .fontSize(11)
                    .borderRadius(14)
                    .backgroundColor($r('app.color.red_color'))
                    .padding(0)
                    .onClick(() => {
                      this.members = this.members.filter((_, i) => i !== index);
                    })
                }
                .width('60%')
                .padding({ top: 4, bottom: 4 })
              }, (member: string, index: number) => member)

              Blank().height(60)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .height('70%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          Scroll() {
            Column({ space: 6 }) {
              Text('Currency')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .margin({ top: 44 })
              Text('Select trip currency')
                .fontSize(12)
                .fontColor('#AAAAAA')
                .textAlign(TextAlign.Center)

              if (this.isSaving) {
                Text('Saving...')
                  .fontSize(11)
                  .fontColor('#AAAAAA')
                  .textAlign(TextAlign.Center)
              }

              ForEach(CURRENCIES, (currency: CurrencyInfo) => {
                Row({ space: 8 }) {
                  Text(currency.symbol)
                    .fontSize(13)
                    .fontColor($r('app.color.blue_color'))
                    .width(24)
                    .textAlign(TextAlign.Center)
                  Column({ space: 2 }) {
                    Text(currency.code)
                      .fontSize(13)
                      .fontColor(this.selectedCurrency.code === currency.code ? '#FFFFFF' : '#CCCCCC')
                      .fontWeight(FontWeight.Medium)
                    Text(currency.name)
                      .fontSize(10)
                      .fontColor('#888888')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (this.selectedCurrency.code === currency.code) {
                    Text('✓')
                      .fontSize(13)
                      .fontColor($r('app.color.blue_color'))
                  }
                }
                .width('75%')
                .padding({
                  top: 6,
                  bottom: 6,
                  left: 12,
                  right: 12
                })
                .borderRadius(10)
                .backgroundColor(
                  this.selectedCurrency.code === currency.code ? '#1A2A4A' : Color.Transparent
                )
                .onClick(() => {
                  this.selectedCurrency = currency;
                })
              }, (currency: CurrencyInfo) => currency.code)

              Blank().height(60)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .height('70%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

        }
        .vertical(true)
        .indicator(false)
        .disableSwipe(true)

        Column() {
          ArcButton({ options: this.topOptions })
          Blank()
          ArcButton({ options: this.bottomOptions })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .hideTitleBar(true)
  }
}