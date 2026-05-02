import { PersonExpense } from '../model/PersonExpense';
import { TripPerson } from '../model/TripPerson';
import { ArcButton, ArcButtonOptions, ArcButtonStyleMode, ArcButtonPosition, ColorMetrics } from '@kit.ArkUI';
import { ExpenseAndPersons } from '../model/ExpenseAndPersons';

@Builder
export function ExpenseDetailPageBuilder() {
  ExpenseDetailPage();
}

@Component
export struct ExpenseDetailPage {
  @Consume pathStack: NavPathStack;
  @State currency: string = '';
  @State expense: PersonExpense | undefined = undefined;
  @State paidByName: string = '';
  @State participants: TripPerson[] = [];
  @State splitAmount: number = 0;
  @State details: string = '';
  private backOptions: ArcButtonOptions = new ArcButtonOptions({
    label: 'back',
    position: ArcButtonPosition.BOTTOM_EDGE,
    styleMode: ArcButtonStyleMode.CUSTOM,
    backgroundColor: ColorMetrics.resourceColor($r('app.color.blue_color')),
    onClick: () => {
      this.pathStack.pop();
    }
  });

  aboutToAppear(): void {
    const params = this.pathStack.getParamByName('ExpenseDetailPage').pop() as ExpenseAndPersons;

    if (!params) {
      return;
    }
    this.currency = params.currency;
    this.expense = params.expense;
    this.paidByName = params.persons.find(p => p.id === params.expense.personId)?.name ?? 'Unknown';
    this.participants = params.persons.filter(p => params.expense.participantsIds.includes(p.id));
    this.splitAmount = params.expense.participantsIds.length > 0
      ? params.expense.amount / params.expense.participantsIds.length
      : params.expense.amount;
    this.details = params.expense.details;
  }

  @Builder
  private buildInfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .textAlign(TextAlign.Start)
        .fontSize('22px')
        .fontColor('#888888')
        .layoutWeight(1)
      Text(value)
        .fontSize('22px')
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  private formatCreatedAt(createdAt: string): string {
    if (!createdAt || createdAt.trim().length === 0) {
      return '';
    }

    if (/^\d{4}-\d{2}-\d{2}$/.test(createdAt)) {
      return createdAt;
    }

    if (/^\d+$/.test(createdAt)) {
      const timestamp = Number(createdAt);
      if (!Number.isNaN(timestamp)) {
        return new Date(timestamp).toISOString().slice(0, 10);
      }
    }

    const parsedDate = new Date(createdAt);
    if (!Number.isNaN(parsedDate.getTime())) {
      return parsedDate.toISOString().slice(0, 10);
    }

    return createdAt;
  }

  build() {
    NavDestination() {
      Stack() {
        if (this.expense) {
          Scroll() {
            Column({ space: 12 }) {

              // Amount header
              Column({ space: 4 }) {
                Text(`${this.currency}${this.expense.amount.toFixed(2)}`)
                  .fontSize('52px')
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#4FC3F7')
                Text(this.formatCreatedAt(this.expense.createdAt))
                  .fontSize('24px')
                  .fontColor('#888888')
              }
              .alignItems(HorizontalAlign.Center)
              .margin({ top: 44, bottom: 4 })

              // Paid by + date card
              Column({ space: 10 }) {
                this.buildInfoRow('Paid by', this.paidByName)
                this.buildInfoRow('Date', this.formatCreatedAt(this.expense.createdAt))
                this.buildInfoRow('Details', `${this.details}`)
                this.buildInfoRow('Total', `${this.currency}${this.expense.amount.toFixed(2)}`)
                this.buildInfoRow('Per person', `${this.currency}${this.splitAmount.toFixed(2)}`)
                this.buildInfoRow('Split among', `${this.participants.length} people`)
                Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
                  ForEach(this.participants, (person: TripPerson) => {
                    Button(person.name)
                      .fontSize('22px')
                      .fontColor(Color.White)
                      .backgroundColor('#4FC3F7')
                      .borderRadius(20)
                      .height(20)
                      .padding(0)
                      .margin({ left: 4, bottom: 4 })
                      .padding({ left: 14, right: 14 })
                  }, (person: TripPerson) => person.id.toString())
                }
                .width('100%')
              }
              .width('78%')
              .padding({
                top: 14,
                bottom: 14,
                left: 10,
                right: 10
              })
              .borderRadius(20)
              .backgroundColor('#26FFFFFF')

              Blank()
                .height(60)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }

        Column() {
          Blank()
          ArcButton({ options: this.backOptions })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .hideTitleBar(true)
  }
}