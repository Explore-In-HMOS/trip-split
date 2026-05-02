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
import { PersonExpense } from '../model/PersonExpense';
import { TripPerson } from '../model/TripPerson';

@Builder
export function AddExpensePageBuilder() {
  AddExpensePage();
}

@Entry
@ComponentV2
struct AddExpensePage {
  pathStack: NavPathStack = new NavPathStack();
  private wearableSwiperController: ArcSwiperController = new ArcSwiperController();
  @Local step: number = 0;
  private readonly maxStep = 3;
  @Local description: string = '';
  @Local amount: string = '';
  @Local paidById: number = -1;
  @Local splitAmongIds: number[] = [];
  @Local errorMessage: string = '';
  @Local persons: TripPerson[] = [];

  private getPersonNameById(id: number): string {
    return this.persons.find(p => p.id === id)?.name ?? 'Unknown';
  }

  private get memberIds(): number[] {
    return this.persons.map(p => p.id);
  }

  private showError(msg: string): void {
    this.errorMessage = msg;
    setTimeout(() => {
      this.errorMessage = '';
    }, 2000);
  }

  private validateCurrentStep(): boolean {
    if (this.step === 0 && this.description.trim().length === 0) {
      this.showError('Please enter a description');
      return false;
    }
    if (this.step === 1) {
      const parsed = parseFloat(this.amount);
      if (this.amount.trim().length === 0 || isNaN(parsed) || parsed <= 0) {
        this.showError('Please enter a valid amount');
        return false;
      }
    }
    if (this.step === 2 && this.paidById === -1) {
      this.showError('Please select who paid');
      return false;
    }
    if (this.step === 3 && this.splitAmongIds.length === 0) {
      this.showError('Select at least one person');
      return false;
    }
    return true;
  }

  private stepLabel(): string {
    return `${this.step + 1}/${this.maxStep + 1}`;
  }

  private topOptions: ArcButtonOptions = new ArcButtonOptions({
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
        this.bottomOptions.label = this.step === this.maxStep ? 'finish' : `next ${this.stepLabel()}`;
        this.wearableSwiperController.showPrevious();
      }
    }
  });
  private bottomOptions: ArcButtonOptions = new ArcButtonOptions({
    label: 'next 1/4',
    position: ArcButtonPosition.BOTTOM_EDGE,
    styleMode: ArcButtonStyleMode.CUSTOM,
    backgroundColor: ColorMetrics.resourceColor($r('app.color.blue_color')),
    fontColor: ColorMetrics.resourceColor(Color.White),
    onClick: () => {
      if (!this.validateCurrentStep()) {
        return;
      }

      if (this.step === this.maxStep) {
        const expenseInfo: PersonExpense = {
          id: -1,
          personId: this.paidById,
          participantsIds: this.splitAmongIds,
          amount: parseFloat(this.amount),
          details: this.description,
          createdAt: Date.now().toString()
        };
        this.pathStack.pop(expenseInfo);
        return;
      }

      this.step++;
      this.errorMessage = '';
      this.topOptions.label = 'previous';
      this.bottomOptions.label = this.step === this.maxStep ? 'finish' : `next ${this.stepLabel()}`;
      this.wearableSwiperController.showNext();
    }
  });

  @Builder
  private buildDescriptionStep() {
    Column({ space: 8 }) {
      Text('New Expense')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
      Text('What was the expense?')
        .fontSize(12)
        .fontColor('#AAAAAA')
        .textAlign(TextAlign.Center)
      TextInput({ placeholder: 'Description', text: this.description })
        .onChange((val) => this.description = val)
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
  }

  @Builder
  private buildAmountStep() {
    Column({ space: 8 }) {
      Text('Amount')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
      Text('How much was it?')
        .fontSize(12)
        .fontColor('#AAAAAA')
        .textAlign(TextAlign.Center)
      TextInput({ placeholder: '0.00', text: this.amount })
        .onChange((val) => this.amount = val)
        .type(InputType.Number)
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
  }

  @Builder
  private buildPaidByStep() {
    Scroll() {
      Column({ space: 6 }) {
        Text('Paid By')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 44 })
        Text('Who paid for this?')
          .fontSize(12)
          .fontColor('#AAAAAA')
          .textAlign(TextAlign.Center)

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(11)
            .fontColor($r('app.color.red_color'))
            .textAlign(TextAlign.Center)
        }

        ForEach(this.memberIds, (id: number) => {
          Row() {
            Text(this.getPersonNameById(id))
              .fontSize(13)
              .fontColor(this.paidById === id ? '#000000' : '#FFFFFF')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          }
          .width('70%')
          .height(36)
          .borderRadius(18)
          .backgroundColor(this.paidById === id ? '#FFFFFF' : '#333333')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.paidById = id;
          })
        }, (id: number) => id.toString())

        Blank().height(60)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 4, bottom: 4 })
    }
    .width('100%')
    .height('70%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private buildSplitAmongStep() {
    Scroll() {
      Column({ space: 6 }) {
        Text('Split Among')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 44 })
        Text('Who shares this expense?')
          .fontSize(12)
          .fontColor('#AAAAAA')
          .textAlign(TextAlign.Center)

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(11)
            .fontColor($r('app.color.red_color'))
            .textAlign(TextAlign.Center)
        }

        ForEach(this.memberIds, (id: number) => {
          Row({ space: 8 }) {
            Text(this.splitAmongIds.includes(id) ? '✓' : '')
              .fontSize(13)
              .fontColor('#000000')
              .width(20)
              .textAlign(TextAlign.Center)
            Text(this.getPersonNameById(id))
              .fontSize(13)
              .fontColor(this.splitAmongIds.includes(id) ? '#000000' : '#FFFFFF')
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
          }
          .width('70%')
          .height(36)
          .borderRadius(18)
          .backgroundColor(this.splitAmongIds.includes(id) ? '#FFFFFF' : '#333333')
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            if (this.splitAmongIds.includes(id)) {
              this.splitAmongIds = this.splitAmongIds.filter(i => i !== id);
            } else {
              this.splitAmongIds = [...this.splitAmongIds, id];
            }
          })
        }, (id: number) => id.toString())

        Blank().height(60)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 4, bottom: 4 })
    }
    .width('100%')
    .height('70%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    NavDestination() {
      Stack() {
        ArcSwiper(this.wearableSwiperController) {
          this.buildDescriptionStep()
          this.buildAmountStep()
          this.buildPaidByStep()
          this.buildSplitAmongStep()
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
      const params = context.pathStack.getParamByName('AddExpensePage').pop() as TripPerson[];
      if (params) {
        this.persons = params;
      }
    })
    .hideTitleBar(true)
  }
}