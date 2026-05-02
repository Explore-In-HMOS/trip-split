import { RdbTable } from './RdbTable';
import { TRIP_PERSON_COLUMNS } from './TripPersonTable';

interface PersonExpenseColumns {
  ID: string;
  PERSON_ID: string;
  PARTICIPANTS_IDS: string;
  AMOUNT: string;
  DETAILS: string;
  CREATED_AT: string;
}

export const PERSON_EXPENSE_COLUMNS: PersonExpenseColumns = {
  ID: 'id',
  PERSON_ID: 'person_id',
  PARTICIPANTS_IDS: 'participants_ids',
  AMOUNT: 'amount',
  DETAILS: 'details',
  CREATED_AT: 'created_at'
}

export const personExpenseTable: RdbTable = {
  tableName: 'PersonExpense',
  createQuery: `
    CREATE TABLE "PersonExpense" (
      ${PERSON_EXPENSE_COLUMNS.ID}	INTEGER NOT NULL,
      ${PERSON_EXPENSE_COLUMNS.PERSON_ID}	INTEGER NOT NULL,
      ${PERSON_EXPENSE_COLUMNS.PARTICIPANTS_IDS}	TEXT NOT NULL,
      ${PERSON_EXPENSE_COLUMNS.AMOUNT}	BLOB NOT NULL,
      ${PERSON_EXPENSE_COLUMNS.DETAILS}	TEXT NOT NULL,
      ${PERSON_EXPENSE_COLUMNS.CREATED_AT}	INTEGER NOT NULL DEFAULT current_date,
      PRIMARY KEY(${PERSON_EXPENSE_COLUMNS.ID} AUTOINCREMENT),
      FOREIGN KEY(${PERSON_EXPENSE_COLUMNS.PERSON_ID}) REFERENCES "TripPerson"(${TRIP_PERSON_COLUMNS.ID}) ON DELETE CASCADE
    );
  `
};
