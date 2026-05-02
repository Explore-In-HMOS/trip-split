import { PersonExpense } from '../model/PersonExpense';
import { TripPerson } from '../model/TripPerson';
import { AppDatabase } from '../database/AppDatabase';
import {
  ArcList,
  ArcListItem,
  LengthMetrics,
  ComponentContent,
  ArcListAttribute,
  ArcListItemAttribute
} from '@kit.ArkUI';
import { Resolve } from '../registry/ServiceRegistry';
import { Trip } from '../model/Trip';
import { PersonExpensesParams } from './PersonExpensesPage';

interface PersonSummary {
  person: TripPerson;
  totalAmount: number;
  expenses: PersonExpense[];
}

@Builder
function tripHeader(tripName: string) {
  Text(tripName)
      .fontColor(Color.White)
      .fontSize('22fp')
      .padding({ top: 10 })
      .fontWeight(FontWeight.Bold)
}

@Entry
@Component
export struct TripPage {
  @Resolve(AppDatabase)
  private database?: AppDatabase;
  @Consume pathStack: NavPathStack;
  @Consume refreshOldTrips: number;
  @State tripName: string = '';
  @State tripId: number = -1;
  @State currency: string = '';
  tripCreatedTime: string = '';
  @State expenses: PersonExpense[] = [];
  @State persons: TripPerson[] = [];
  @State personSummaries: PersonSummary[] = [];
  @State isLoading: boolean = false;
  context: UIContext = this.getUIContext();
  arcListHeader: ComponentContent<string> = new ComponentContent(
    this.context,
    wrapBuilder<[string]>(tripHeader),
    this.tripName
  );

  async aboutToAppear(): Promise<void> {
    if (!this.database) {
      return;
    }

    const params = this.pathStack.getParamByName('TripPage').pop() as Trip;
    if (params?.id) {
      this.tripId = params.id;
      this.tripName = params.name;
      this.currency = params.currency;
      await this.database.setCurrentTrip(params.id);
    } else {
      const savedTripId = await this.database.getCurrentTripId();
      if (savedTripId !== -1) {
        this.tripId = savedTripId;
        const trips = await this.database.getTrips();
        const found = trips.find(t => t.id === savedTripId);
        this.tripName = found?.name ?? '';
        this.currency = found?.currency ?? '';
      }
    }

    this.arcListHeader = new ComponentContent(
      this.context,
      wrapBuilder<[string]>(tripHeader),
      this.tripName
    );

    await this.loadTripData();
  }

  private async loadTripData(): Promise<void> {
    this.isLoading = true;
    try {
      if (this.database) {
        const db = this.database;
        this.persons = await this.database.getTripPersons(this.tripId);

        const expenseArrays = await Promise.all(
          this.persons.map(person => db.getPersonExpenses(person.id))
        );

        this.expenses = expenseArrays
          .flat()
          .sort((a, b) => b.createdAt.localeCompare(a.createdAt));

        // Build per-person summaries
        this.personSummaries = this.persons.map(person => {
          const personExpenses = this.expenses.filter(e => e.personId === person.id);
          const totalAmount = personExpenses.reduce((sum, e) => sum + e.amount, 0);
          return {
            person,
            totalAmount,
            expenses: personExpenses
          } as PersonSummary;
        }).filter(s => s.expenses.length > 0);
      }
    } catch (error) {
      console.error(`Failed to load trip data: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  private async updateTripFinishDate(tripToFinish: Trip, finishedAt: string){
    const res: number | undefined = await this.database?.updateTripFinishDate(this.tripId, finishedAt)
    if (res !== undefined && res !== -1) {
      this.database!.clearCurrentTrip()
        .then(() => {
          this.refreshOldTrips += 1;
          this.tripName = '';
          this.tripId = -1;
          this.expenses = [];
          this.persons = [];
          this.personSummaries = [];
          this.pathStack.pushPathByName('TripAnalysisPage', tripToFinish);
        });
    }
  }

  build() {
    Column() {
      if (this.tripName === '') {
        Column() {
          Button('Create trip')
            .backgroundColor($r('app.color.blue_color'))
            .height(80)
            .borderRadius(40)
            .onClick(() => {
              this.pathStack.pushPathByName('AddTripPage', null, async (popInfo) => {
                const trip = popInfo.result as Trip;
                if (!trip || !this.database) {
                  return;
                }

                await this.database.setCurrentTrip(trip.id);

                this.tripId = trip.id;
                this.tripName = trip.name;
                this.currency = trip.currency;
                this.tripCreatedTime = trip.createdAt;

                this.arcListHeader = new ComponentContent(
                  this.context,
                  wrapBuilder<[string]>(tripHeader),
                  this.tripName
                );

                await this.loadTripData();
              }, true);
            })
        }
        .justifyContent(FlexAlign.Center)
        .height('100%')
        .width('100%')

      } else {
        ArcList({ initialIndex: 0, header: this.arcListHeader }) {

          if (this.isLoading) {
            ArcListItem() {
              Row() {
                Text('Loading...')
                  .fontColor('#888888')
                  .fontSize('20px')
              }
              .justifyContent(FlexAlign.Center)
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }
            .width('414px')
            .height('129px')
            .borderRadius('65px')
            .backgroundColor('#26FFFFFF')
          }

          // Add expense button
          ArcListItem() {
            Row() {
              Text('Add expense')
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
          .backgroundColor($r('app.color.blue_color'))
          .onClick(() => {
            this.pathStack.pushPathByName('AddExpensePage', this.persons, async (popInfo) => {
              const expenseInfo = popInfo.result as PersonExpense;
              if (!expenseInfo || !this.database) {
                return;
              }

              await this.database.insertPersonExpense(
                expenseInfo.personId,
                expenseInfo.participantsIds,
                expenseInfo.amount,
                expenseInfo.details,
                expenseInfo.createdAt
              );

              await this.loadTripData();
            }, true);
          })

          // Per-person summary rows
          ForEach(this.personSummaries, (summary: PersonSummary) => {
            ArcListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text(summary.person.name)
                    .fontSize('38px')
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                  Text(`${summary.expenses.length} expense${summary.expenses.length !== 1 ? 's' : ''}`)
                    .fontSize('20px')
                    .fontColor('#888888')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(`${this.currency}${summary.totalAmount.toFixed(2)}`)
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
              const params: PersonExpensesParams = {
                person: summary.person,
                expenses: summary.expenses,
                currency: this.currency,
                persons: this.persons
              };
              this.pathStack.pushPathByName('PersonExpensesPage', params);
            })
          }, (summary: PersonSummary) => `${summary.person.id}-${summary.expenses.length}-${summary.totalAmount.toFixed(2)}`)

          // Finish trip button
          ArcListItem() {
            Row() {
              Text('Finish trip')
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
          .backgroundColor($r('app.color.red_color'))
          .onClick(() => {
            if (!this.database) {
              return;
            }
            const finishedAt = new Date().toISOString();
            const tripToFinish: Trip = {
              id: this.tripId,
              name: this.tripName,
              currency: this.currency,
              createdAt: this.tripCreatedTime,
              finishedAt: finishedAt
            };

            this.updateTripFinishDate(tripToFinish, finishedAt);
          })
        }
        .width('100%')
        .height('100%')
        .space(LengthMetrics.px(10))
        .scrollBar(BarState.Auto)
      }
    }
    .height('100%')
    .width('100%')
  }
}
