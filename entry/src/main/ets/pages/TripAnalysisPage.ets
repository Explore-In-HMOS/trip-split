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
  ComponentContent,
  ColorMetrics,
  ArcListAttribute,
  ArcListItemAttribute
} from '@kit.ArkUI';
import { Debt, Payment, Trip } from '../model/Trip';

@Builder
function analysisHeader(tripName: string) {
  Text(tripName)
      .fontColor(Color.White)
      .fontSize('22fp')
      .padding({ top: 10 })
      .fontWeight(FontWeight.Bold)
}

@Builder
export function TripAnalysisPageBuilder() {
  TripAnalysisPage();
}

@Component
export struct TripAnalysisPage {
  @Consume pathStack: NavPathStack;
  @Resolve(AppDatabase)
  private database?: AppDatabase;
  @State trip: Trip | undefined = undefined;
  @State persons: TripPerson[] = [];
  @State isLoading: boolean = true;
  context: UIContext = this.getUIContext();
  arcListHeader: ComponentContent<string> | undefined = undefined;
  private backOptions: ArcButtonOptions = new ArcButtonOptions({
    label: 'ok',
    position: ArcButtonPosition.BOTTOM_EDGE,
    styleMode: ArcButtonStyleMode.CUSTOM,
    onClick: () => {
      this.pathStack.clear();
    }
  });

  async aboutToAppear(): Promise<void> {
    try {
      this.backOptions.fontColor = ColorMetrics.resourceColor(Color.White);
      this.backOptions.backgroundColor = ColorMetrics.resourceColor($r('app.color.blue_color'));
    } catch (_) {
    }

    const params = this.pathStack.getParamByName('TripAnalysisPage').pop() as Trip;
    if (!params || !this.database) {
      return;
    }

    this.trip = params;

    this.arcListHeader = new ComponentContent(
      this.context,
      wrapBuilder<[string]>(analysisHeader),
      params.name
    );

    this.persons = await this.database.getTripPersons(params.id);

    // Calculate and save analysis only if not already present
    if (!params.paymentsPerPerson?.length && !params.debts?.length) {
      const calculated = await this.calculateAnalysis();
      this.trip = calculated;
      await this.database.insertTripAnalysis(calculated);
    }

    this.isLoading = false;
  }

  private async calculateAnalysis(): Promise<Trip> {
    const db = this.database!;
    const trip = this.trip!;

    const expenseArrays = await Promise.all(
      this.persons.map(person => db.getPersonExpenses(person.id))
    );
    const allExpenses = expenseArrays.flat();

    const totalAmount = allExpenses.reduce((sum, e) => sum + e.amount, 0);

    const paidMap = new Map<number, number>();
    this.persons.forEach(p => paidMap.set(p.id, 0));
    allExpenses.forEach(e => {
      paidMap.set(e.personId, (paidMap.get(e.personId) ?? 0) + e.amount);
    });

    const owesMap = new Map<number, number>();
    this.persons.forEach(p => owesMap.set(p.id, 0));
    allExpenses.forEach(e => {
      const share = e.amount / e.participantsIds.length;
      e.participantsIds.forEach(pid => {
        owesMap.set(pid, (owesMap.get(pid) ?? 0) + share);
      });
    });

    const paymentsPerPerson: Payment[] = this.persons.map(p => ({
      fromPersonId: p.id,
      paidAmount: paidMap.get(p.id) ?? 0,
      spentAmount: owesMap.get(p.id) ?? 0
    } as Payment));

    const balanceMap = new Map<number, number>();
    this.persons.forEach(p => {
      balanceMap.set(p.id, (paidMap.get(p.id) ?? 0) - (owesMap.get(p.id) ?? 0));
    });

    const creditors = this.persons
      .filter(p => (balanceMap.get(p.id) ?? 0) > 0.001)
      .map(p => ({ fromPersonId: p.id, balance: balanceMap.get(p.id)! } as Debt));
    const debtors = this.persons
      .filter(p => (balanceMap.get(p.id) ?? 0) < -0.001)
      .map(p => ({ fromPersonId: p.id, balance: balanceMap.get(p.id)! } as Debt));

    const debts: Debt[] = [];
    let ci = 0;
    let di = 0;
    while (ci < creditors.length && di < debtors.length) {
      const creditor = creditors[ci];
      const debtor = debtors[di];
      const amount = Math.min(creditor.balance, -debtor.balance);
      debts.push({
        fromPersonId: debtor.fromPersonId,
        toPersonId: creditor.fromPersonId,
        balance: Math.round(amount * 100) / 100
      });
      creditor.balance -= amount;
      debtor.balance += amount;
      if (creditor.balance < 0.001) {
        ci++;
      }
      if (debtor.balance > -0.001) {
        di++;
      }
    }
    const result: Trip = {
      id: trip.id,
      name: trip.name,
      currency: trip.currency,
      createdAt: trip.createdAt,
      finishedAt: trip.finishedAt,
      totalAmount: totalAmount,
      paymentsPerPerson: paymentsPerPerson,
      debts: debts
    }
    return result;
  }

  getPersonNameById(id: number): string {
    return this.persons.find(p => p.id === id)?.name ?? 'Unknown';
  }

  build() {
    NavDestination() {
      Stack() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .color(Color.White)
              .width(36)
              .height(36)
            Text('Calculating...')
              .fontSize('14fp')
              .fontColor('#AAAAAA')
              .margin({ top: 10 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

        } else if (this.trip) {
          ArcList({ header: this.arcListHeader }) {

            ArcListItem() {
              Column() {
                Text('TOTAL')
                  .fontSize('11fp')
                  .fontColor('#888888')
                  .letterSpacing(1)
                  .margin({ bottom: 4 })
                Row() {
                  Text(this.trip!.currency)
                    .fontSize('16fp')
                    .fontColor('#AAAAAA')
                    .alignSelf(ItemAlign.End)
                    .margin({ bottom: 2 })
                  Text(this.trip.totalAmount?.toFixed(2))
                    .fontSize('28fp')
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                }
                .alignItems(VerticalAlign.Bottom)

                Text(`${this.persons.length} people`)
                  .fontSize('12fp')
                  .fontColor('#888888')
                  .margin({ top: 4 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .padding({ top: 16, bottom: 16 })
            }

            ForEach(this.trip!.paymentsPerPerson, (payment: Payment) => {
              ArcListItem() {
                Column() {
                  Row() {
                    Text(this.getPersonNameById(payment.fromPersonId))
                      .fontSize('14fp')
                      .fontColor(Color.White)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .flexShrink(1)
                    Text(`paid ${this.trip!.currency}${payment.paidAmount.toFixed(2)}`)
                      .fontSize('14fp')
                      .fontColor($r('app.color.blue_color'))
                      .fontWeight(FontWeight.Bold)
                      .flexShrink(0)
                      .margin({ left: 6 })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)

                  Text(`spent ${this.trip!.currency}${payment.spentAmount.toFixed(2)}`)
                    .fontWeight(FontWeight.Bold)
                    .fontSize('14fp')
                    .fontColor($r('app.color.red_color'))
                    .margin({ top: 2 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
                .padding({
                  top: 10,
                  bottom: 10,
                  left: 16,
                  right: 16
                })
              }
            }, (payment: Payment) => payment.fromPersonId.toString())

            ArcListItem() {
              Text('OWES')
                .fontSize('11fp')
                .fontColor('#888888')
                .letterSpacing(1)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 8, bottom: 4 })
            }

            if (this.trip!.debts?.length === 0) {
              ArcListItem() {
                Text('All settled up!')
                  .fontSize('14fp')
                  .fontColor('#888888')
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 10, bottom: 10 })
              }
            } else {
              ForEach(this.trip!.debts, (debt: Debt) => {
                ArcListItem() {
                  Row() {
                    Column() {
                      Text(`${this.getPersonNameById(debt.fromPersonId)} → ${this.getPersonNameById(debt.toPersonId)}`)
                        .fontSize('13fp')
                        .fontColor(Color.White)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .flexGrow(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: 10 })

                    Text(`${this.trip!.currency}${debt.balance.toFixed(2)}`)
                      .fontSize('14fp')
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.blue_color'))
                      .flexShrink(0)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                  .padding({
                    top: 10,
                    bottom: 10,
                    left: 16,
                    right: 16
                  })
                }
              }, (debt: Debt) => `${debt.fromPersonId}-${debt.toPersonId}`)

              ArcListItem() {
                Row() {
                  Text('View expenses')
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                }
                .justifyContent(FlexAlign.Center)
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
              .borderWidth(2)
              .borderColor(Color.White)
              .backgroundColor($r('app.color.purple_color'))
              .onClick(() => {
                this.pathStack.pushPathByName('OldTripExpensesPage', this.trip);
              })
            }
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
        }

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