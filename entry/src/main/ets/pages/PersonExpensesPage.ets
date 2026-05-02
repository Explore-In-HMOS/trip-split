import { PersonExpense } from '../model/PersonExpense';
import { TripPerson } from '../model/TripPerson';
import {
  ArcButton,
  ArcButtonOptions,
  ArcButtonStyleMode,
  ArcButtonPosition,
  ColorMetrics,
  ArcList,
  ArcListItem,
  LengthMetrics,
  ComponentContent,
  ArcListAttribute,
  ArcListItemAttribute
} from '@kit.ArkUI';
import { ExpenseAndPersons } from '../model/ExpenseAndPersons';

export interface PersonExpensesParams {
  person: TripPerson;
  expenses: PersonExpense[];
  currency: string;
  persons: TripPerson[];
}

@Builder
function pageHeader(personName: string) {
  Text(`${personName}'s Expenses`)
      .fontColor(Color.White)
      .fontSize('22fp')
      .padding({ top: 10 })
      .fontWeight(FontWeight.Bold)
}

@Builder
export function PersonExpensesPageBuilder() {
  PersonExpensesPage();
}

@Component
export struct PersonExpensesPage {
  @Consume pathStack: NavPathStack;
  @State currency: string = '';
  @State person: TripPerson | undefined = undefined;
  @State expenses: PersonExpense[] = [];
  @State persons: TripPerson[] = [];
  context: UIContext = this.getUIContext();
  arcListHeader: ComponentContent<string> = new ComponentContent(
    this.context,
    wrapBuilder<[string]>(pageHeader),
    ''
  );
  private backOptions: ArcButtonOptions = new ArcButtonOptions({
    label: 'Back',
    position: ArcButtonPosition.BOTTOM_EDGE,
    styleMode: ArcButtonStyleMode.CUSTOM,
    backgroundColor: ColorMetrics.resourceColor($r('app.color.blue_color')),
    onClick: () => {
      this.pathStack.pop();
    }
  });

  aboutToAppear(): void {
    const params = this.pathStack.getParamByName('PersonExpensesPage').pop() as PersonExpensesParams;
    if (!params) {
      return;
    }
    this.currency = params.currency;
    this.person = params.person;
    this.expenses = params.expenses.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    this.persons = params.persons;

    this.arcListHeader = new ComponentContent(
      this.context,
      wrapBuilder<[string]>(pageHeader),
      params.person.name
    );
  }

  getParticipantNames(participantsIds: number[]): string {
    return participantsIds
      .map(id => this.persons.find(p => p.id === id)?.name ?? 'Unknown')
      .join(', ');
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
        ArcList({ initialIndex: 0, header: this.arcListHeader }) {
          ForEach(this.expenses, (expense: PersonExpense) => {
            ArcListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text(expense.details?.length > 0 ? expense.details : 'Expense')
                    .fontSize('34px')
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.formatCreatedAt(expense.createdAt))
                    .fontSize('20px')
                    .fontColor('#888888')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(`${this.currency}${expense.amount.toFixed(2)}`)
                  .fontSize('34px')
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
              if (!this.person) {
                return;
              }
              const info: ExpenseAndPersons = {
                expense: expense,
                persons: this.persons,
                currency: this.currency
              };
              this.pathStack.pushPathByName('ExpenseDetailPage', info);
            })
          }, (expense: PersonExpense) => expense.id.toString())

          // Bottom padding item
          ArcListItem() {
            Row()
          }
          .width('414px')
          .height('60px')
          .backgroundColor(Color.Transparent)
        }
        .width('100%')
        .height('100%')
        .space(LengthMetrics.px(10))
        .scrollBar(BarState.Auto)

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