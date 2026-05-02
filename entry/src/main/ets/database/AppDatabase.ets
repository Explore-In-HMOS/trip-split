import Logger from '../utils/Logger';
import { BusinessError } from '@kit.BasicServicesKit';
import Injectable from '../registry/Injectable';
import { relationalStore } from '@kit.ArkData';
import { tripPersonTable, TRIP_PERSON_COLUMNS } from './table/TripPersonTable';
import { tripTable, TRIP_COLUMNS } from './table/TripTable';
import { personExpenseTable, PERSON_EXPENSE_COLUMNS } from './table/PersonExpenseTable';
import { Debt, Payment, Trip } from '../model/Trip';
import { TripPerson } from '../model/TripPerson';
import { PersonExpense } from '../model/PersonExpense';

export class AppDatabase extends Injectable {
  private readonly readyDatabase: Promise<relationalStore.RdbStore>;

  constructor(context: Context) {
    super();
    this.readyDatabase = this.initRdb(context)
      .then((store) => {
        Logger.info(`Succeeded in getting RdbStore, version: ${store.version}`);
        return store
      })
      .catch((err: BusinessError) => {
        const message = `Failed to get RdbStore. Code:${err.code}, message:${err.message}`;
        Logger.error(message);
        throw new Error(message);
      });
  }

  /**
   * Initialize Rdb variable.
   * @throws { BusinessError } error when getting or query execution fails
   * @param context { Context }
   * @returns { Promise<relationalStore.RdbStore> }
   */
  private async initRdb(context: Context): Promise<relationalStore.RdbStore> {
    const store = await relationalStore.getRdbStore(context, {
      name: 'trip_split.db',
      securityLevel: relationalStore.SecurityLevel.S1
    });

    if (store.version === 0) {
      await this.runCreationQueries(store);
      store.version = 1;
    }
    return store;
  }

  async setCurrentTrip(tripId: number): Promise<void> {
    const database = await this.readyDatabase;
    try {
      // Clear current flag from all trips first
      await database.executeSql(`UPDATE "${tripTable.tableName}" SET ${TRIP_COLUMNS.IS_CURRENT} = 0`);
      // Set current flag on the selected trip
      const predicates = new relationalStore.RdbPredicates(tripTable.tableName)
        .equalTo(TRIP_COLUMNS.ID, tripId);
      await database.update({ 'is_current': 1 }, predicates);
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to set current trip. Code:${err.code}, message:${err.message}`);
    }
  }

  async getCurrentTripId(): Promise<number> {
    const database = await this.readyDatabase;
    const predicates = new relationalStore.RdbPredicates(tripTable.tableName)
      .equalTo(TRIP_COLUMNS.IS_CURRENT, 1);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await database.query(predicates);
      if (!resultSet || resultSet.rowCount === 0) {
        return -1;
      }
      resultSet.goToNextRow();
      return resultSet.getLong(resultSet.getColumnIndex(TRIP_COLUMNS.ID));
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to get current trip. Code:${err.code}, message:${err.message}`);
      return -1;
    } finally {
      resultSet?.close();
    }
  }

  private async runCreationQueries(store: relationalStore.RdbStore): Promise<void> {
    try {
      await store.executeSql(tripTable.createQuery);
      await store.executeSql(tripPersonTable.createQuery);
      await store.executeSql(personExpenseTable.createQuery);
    } catch (error) {
      const err = error as BusinessError;
      const message = `Failed to create database tables. Code:${err.code}, message:${err.message}`;
      Logger.error(message);
      throw new Error(message);
    }
  }

  async onDispose(): Promise<void> {
    const database = await this.readyDatabase;
    database.close().catch((err: BusinessError) => {
      Logger.error(`Failed to close RdbStore. Code:${err.code}, message:${err.message}`);
    });
  }

  async hasTripWithName(name: string): Promise<boolean> {
    const normalizedName = name.trim().toLocaleLowerCase();
    const trips = await this.getTrips();
    return trips.some(trip => trip.name.trim().toLocaleLowerCase() === normalizedName);
  }

  async hasTripPersonWithName(tripId: number, personName: string): Promise<boolean> {
    const normalizedName = personName.trim().toLocaleLowerCase();
    const persons = await this.getTripPersons(tripId);
    return persons.some(person => person.name.trim().toLocaleLowerCase() === normalizedName);
  }

  async insertTrip(name: string, currency: string, createdAt: string): Promise<number> {
    const database = await this.readyDatabase;

    if (!database) {
      return -1;
    }

    try {
      if (await this.hasTripWithName(name)) {
        Logger.warn(`Trip name already exists: ${name}`);
        return -1;
      }
      // Insert new trip
      const result: number =
        await database.insert(tripTable.tableName, { 'name': name, 'currency': currency, 'created_at': createdAt });
      return result;
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Insert user failed, code is ${err.code}, message is ${err.message}`);
      return -1;
    }
  }

  async getTrips(): Promise<Trip[]> {
    const database = await this.readyDatabase;
    const predicates = new relationalStore.RdbPredicates(tripTable.tableName).orderByDesc(TRIP_COLUMNS.CREATED_AT);
    try {
      let resultSet: relationalStore.ResultSet | undefined = undefined;
      try {
        resultSet = await database.query(predicates);
        if (!resultSet || resultSet.rowCount === 0) {
          return [];
        }

        const results: Trip[] = [];
        while (resultSet.goToNextRow()) {
          const paymentsRaw = resultSet.getString(resultSet.getColumnIndex(TRIP_COLUMNS.PAYMENTS_PER_PERSON));
          const debtsRaw = resultSet.getString(resultSet.getColumnIndex(TRIP_COLUMNS.DEBTS));

          const trip: Trip = {
            id: resultSet.getLong(resultSet.getColumnIndex(TRIP_COLUMNS.ID)),
            name: resultSet.getString(resultSet.getColumnIndex(TRIP_COLUMNS.NAME)),
            currency: resultSet.getString(resultSet.getColumnIndex(TRIP_COLUMNS.CURRENCY)),
            createdAt: resultSet.getString(resultSet.getColumnIndex(TRIP_COLUMNS.CREATED_AT)),
            finishedAt: resultSet.getString(resultSet.getColumnIndex(TRIP_COLUMNS.FINISHED_AT)),
            totalAmount: resultSet.getDouble(resultSet.getColumnIndex(TRIP_COLUMNS.TOTAL_AMOUNT)),
            paymentsPerPerson: paymentsRaw ? JSON.parse(paymentsRaw) as Payment[] : [],
            debts: debtsRaw ? JSON.parse(debtsRaw) as Debt[] : []
          };
          results.push(trip);
        }
        return results;
      } catch (err) {
        Logger.error(`Failed to get Saved Destinations, Code:${err.code}, message:${err.message}`);
        return [];
      } finally {
        resultSet?.close();
      }
    } catch (err) {
      return [];
    }
  }

  async updateTripFinishDate(tripId: number, finishDate: string): Promise<number> {
    const database = await this.readyDatabase;

    if (!database) {
      return -1;
    }

    try {
      const predicates = new relationalStore.RdbPredicates(tripTable.tableName)
        .equalTo(TRIP_COLUMNS.ID, tripId);
      const result: number = await database.update({ 'finished_at': finishDate }, predicates);
      return result;
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Insert user failed, code is ${err.code}, message is ${err.message}`);
      return -1;
    }
  }

  async insertTripPerson(tripId: number, personName: string): Promise<number> {
    const database = await this.readyDatabase;

    if (!database) {
      return -1;
    }

    try {
      if (await this.hasTripPersonWithName(tripId, personName)) {
        Logger.warn(`Trip person name already exists for trip ${tripId}: ${personName}`);
        return -1;
      }
      // Insert new trip person
      const result: number = await database.insert(tripPersonTable.tableName, {
        'name': personName,
        'trip_id': tripId
      });
      return result;
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Insert user failed, code is ${err.code}, message is ${err.message}`);
      return -1;
    }
  }

  async getTripPersons(tripId: number): Promise<TripPerson[]> {
    const database = await this.readyDatabase;
    const predicates = new relationalStore.RdbPredicates(tripPersonTable.tableName)
      .equalTo(TRIP_PERSON_COLUMNS.TRIP_ID, tripId)
      .orderByDesc(TRIP_PERSON_COLUMNS.ID);
    try {
      let resultSet: relationalStore.ResultSet | undefined = undefined;
      try {
        resultSet = await database.query(predicates);
        if (!resultSet || resultSet.rowCount === 0) {
          return [];
        }

        const results: TripPerson[] = [];
        while (resultSet.goToNextRow()) {
          const person: TripPerson = {
            id: resultSet.getLong(resultSet.getColumnIndex(TRIP_PERSON_COLUMNS.ID)),
            name: resultSet.getString(resultSet.getColumnIndex(TRIP_PERSON_COLUMNS.NAME)),
            tripId: resultSet.getLong(resultSet.getColumnIndex(TRIP_PERSON_COLUMNS.TRIP_ID))
          };

          results.push(person);
        }
        return results;
      } catch (err) {
        Logger.error(`Failed to get Saved Destinations, Code:${err.code}, message:${err.message}`);
        return [];
      } finally {
        resultSet?.close();
      }
    } catch (err) {
      return [];
    }
  }

  async insertPersonExpense(personId: number, participantsIds: number[], amount: number,
    details: string, createdAt: string): Promise<number> {
    const database = await this.readyDatabase;

    if (!database) {
      return -1;
    }

    try {
      if (!participantsIds) {
        throw Error(`participantsIds is empty`);
      }
      // Insert new person expense
      const participantsIdsStr = JSON.stringify(participantsIds);
      const result: number = await database.insert(personExpenseTable.tableName, {
        'person_id': personId,
        'participants_Ids': participantsIdsStr,
        'amount': amount,
        'details': details,
        'created_at': createdAt
      });
      return result;
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Insert user failed, code is ${err.code}, message is ${err.message}`);
      return -1;
    }
  }

  async getPersonExpenses(personId: number): Promise<PersonExpense[]> {
    const database = await this.readyDatabase;
    const predicates = new relationalStore.RdbPredicates(personExpenseTable.tableName)
      .equalTo(PERSON_EXPENSE_COLUMNS.PERSON_ID, personId)
      .orderByDesc(PERSON_EXPENSE_COLUMNS.CREATED_AT);
    try {
      let resultSet: relationalStore.ResultSet | undefined = undefined;
      try {
        resultSet = await database.query(predicates);
        if (!resultSet || resultSet.rowCount === 0) {
          return [];
        }

        const results: PersonExpense[] = [];
        while (resultSet.goToNextRow()) {
          const participantIdsStr =
            resultSet.getString(resultSet.getColumnIndex(PERSON_EXPENSE_COLUMNS.PARTICIPANTS_IDS));
          const personExpenses: PersonExpense = {
            id: resultSet.getLong(resultSet.getColumnIndex(PERSON_EXPENSE_COLUMNS.ID)),
            personId: resultSet.getLong(resultSet.getColumnIndex(PERSON_EXPENSE_COLUMNS.PERSON_ID)),
            participantsIds: JSON.parse(participantIdsStr),
            amount: resultSet.getLong(resultSet.getColumnIndex(PERSON_EXPENSE_COLUMNS.AMOUNT)),
            details: resultSet.getString(resultSet.getColumnIndex(PERSON_EXPENSE_COLUMNS.DETAILS)),
            createdAt: resultSet.getString(resultSet.getColumnIndex(PERSON_EXPENSE_COLUMNS.CREATED_AT))
          };

          results.push(personExpenses);
        }
        return results;
      } catch (err) {
        Logger.error(`Failed to get Saved Destinations, Code:${err.code}, message:${err.message}`);
        return [];
      } finally {
        resultSet?.close();
      }
    } catch (err) {
      return [];
    }
  }

  async insertTripAnalysis(trip: Trip): Promise<void> {
    const database = await this.readyDatabase;
    if (!database) {
      return;
    }

    try {
      const predicates = new relationalStore.RdbPredicates(tripTable.tableName)
        .equalTo(TRIP_COLUMNS.ID, trip.id);
      await database.update({
        'total_amount': trip.totalAmount,
        'payments_per_person': JSON.stringify(trip.paymentsPerPerson),
        'debts': JSON.stringify(trip.debts)
      }, predicates);
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to insert trip analysis. Code:${err.code}, message:${err.message}`);
    }
  }

  async clearCurrentTrip(): Promise<void> {
    const database = await this.readyDatabase;
    try {
      await database.executeSql(`UPDATE "${tripTable.tableName}" SET ${TRIP_COLUMNS.IS_CURRENT} = 0`);
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to clear current trip. Code:${err.code}, message:${err.message}`);
    }
  }
}