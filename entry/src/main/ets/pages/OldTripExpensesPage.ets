import { PersonExpense } from '../model/PersonExpense';
import { TripPerson } from '../model/TripPerson';
import { AppDatabase } from '../database/AppDatabase';
import { Resolve } from '../registry/ServiceRegistry';
import {
  ArcButton,
  ArcButtonOptions,
  ArcButtonStyleMode,
  ArcButtonPosition,
  ArcList,
  ArcListItem,
  LengthMetrics,
  ComponentContent,
  ArcListAttribute,
  ArcListItemAttribute,
  ColorMetrics
} from '@kit.ArkUI';
import { ExpenseAndPersons } from '../model/ExpenseAndPersons';
import { Trip } from '../model/Trip';

@Builder
function expensesHeader(tripName: string) {
  Text(tripName)
      .fontColor(Color.White)
      .fontSize('22fp')
      .padding({ top: 10 })
      .fontWeight(FontWeight.Bold)
}

@Builder
export function OldTripExpensesPageBuilder() {
  OldTripExpensesPage();
}

@Component
export struct OldTripExpensesPage {
  @Consume pathStack: NavPathStack;
  @Resolve(AppDatabase)
  private database?: AppDatabase;
  @State expenses: PersonExpense[] = [];
  @State persons: TripPerson[] = [];
  @State isLoading: boolean = true;
  @State tripName: string = '';
  tripId: number = -1;
  @State currency: string = '';
  context: UIContext = this.getUIContext();
  arcListHeader: ComponentContent<string> | undefined = undefined;
  private backOptions: ArcButtonOptions = new ArcButtonOptions({
    label: 'back',
    position: ArcButtonPosition.BOTTOM_EDGE,
    styleMode: ArcButtonStyleMode.CUSTOM,
    backgroundColor: ColorMetrics.resourceColor($r('app.color.blue_color')),
    fontColor: ColorMetrics.resourceColor(Color.White),
    onClick: () => {
      this.pathStack.pop();
    }
  });

  async aboutToAppear(): Promise<void> {
    const params = this.pathStack.getParamByName('OldTripExpensesPage').pop() as Trip;
    if (!params || !this.database) {
      return;
    }

    this.tripId = params.id;
    this.tripName = params.name;
    this.currency = params.currency;

    this.arcListHeader = new ComponentContent(
      this.context,
      wrapBuilder<[string]>(expensesHeader),
      this.tripName
    );

    await this.loadExpenses();
  }

  private async loadExpenses(): Promise<void> {
    if (!this.database) {
      return;
    }
    this.isLoading = true;
    try {
      this.persons = await this.database.getTripPersons(this.tripId);
      const expenseArrays = await Promise.all(
        this.persons.map(p => this.database!.getPersonExpenses(p.id))
      );
      this.expenses = expenseArrays
        .flat()
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    } catch (error) {
      console.error(`Failed to load expenses: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  getPersonNameById(id: number): string {
    return this.persons.find(p => p.id === id)?.name ?? 'Unknown';
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
        ArcList({ header: this.arcListHeader }) {

          if (this.isLoading) {
            ArcListItem() {
              Row() {
                LoadingProgress()
                  .color(Color.White)
                  .width(24)
                  .height(24)
                Text('Loading...')
                  .fontColor('#888888')
                  .fontSize('20px')
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

          if (!this.isLoading && this.expenses.length === 0) {
            ArcListItem() {
              Text('No expenses')
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

          ForEach(this.expenses, (expense: PersonExpense) => {
            ArcListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text(expense.details)
                    .fontSize('38px')
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                  Text(this.formatCreatedAt(expense.createdAt))
                    .fontSize('20px')
                    .fontColor('#888888')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(`${this.currency}${expense.amount.toFixed(2)}`)
                  .fontSize('38px')
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.blue_color'))
              }
              .width('100%')
              .padding({
                top: 10,
                bottom: 10,
                left: 20,
                right: 20
              })
            }
            .width('414px')
            .height('129px')
            .borderRadius('65px')
            .backgroundColor('#26FFFFFF')
            .onClick(() => {
              const info: ExpenseAndPersons = {
                expense: expense,
                persons: this.persons,
                currency: this.currency
              };
              this.pathStack.pushPathByName('ExpenseDetailPage', info);
            })
          }, (expense: PersonExpense) => expense.id.toString())

          ArcListItem() {
            Row() {
              Blank()
                .height('60px')
            }
          }
        }
        .width('100%')
        .height('100%')
        .space(LengthMetrics.px(10))
        .scrollBar(BarState.Off)

        Column() {
          Blank()
          ArcButton({ options: this.backOptions })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
    }
    .hideTitleBar(true)
  }
}