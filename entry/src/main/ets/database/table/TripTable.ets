import { RdbTable } from './RdbTable';

interface TripColumns {
  ID: string;
  NAME: string;
  CURRENCY: string;
  CREATED_AT: string;
  FINISHED_AT: string;
  IS_CURRENT: string;
  TOTAL_AMOUNT: string;
  PAYMENTS_PER_PERSON: string;
  DEBTS: string;
}

export const TRIP_COLUMNS: TripColumns = {
  ID: 'id',
  NAME: 'name',
  CURRENCY: 'currency',
  CREATED_AT: 'created_at',
  FINISHED_AT: 'finished_at',
  IS_CURRENT: 'is_current',
  TOTAL_AMOUNT: 'total_amount',
  PAYMENTS_PER_PERSON: 'payments_per_person',
  DEBTS: 'debts'
}

export const tripTable: RdbTable = {
  tableName: 'Trip',
  createQuery: `
    CREATE TABLE "Trip" (
      ${TRIP_COLUMNS.ID}	INTEGER NOT NULL,
      ${TRIP_COLUMNS.NAME}	TEXT NOT NULL,
      ${TRIP_COLUMNS.CURRENCY}	TEXT NOT NULL,
      ${TRIP_COLUMNS.CREATED_AT}	TEXT NOT NULL DEFAULT current_date,
      ${TRIP_COLUMNS.FINISHED_AT}	TEXT DEFAULT NULL,
      ${TRIP_COLUMNS.IS_CURRENT}  INTEGER NOT NULL DEFAULT 0,
      ${TRIP_COLUMNS.TOTAL_AMOUNT}        REAL DEFAULT NULL,
      ${TRIP_COLUMNS.PAYMENTS_PER_PERSON} TEXT DEFAULT NULL,
      ${TRIP_COLUMNS.DEBTS}               TEXT DEFAULT NULL,
      PRIMARY KEY(${TRIP_COLUMNS.ID} AUTOINCREMENT)
    );
  `
};
