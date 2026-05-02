import { RdbTable } from './RdbTable';
import { TRIP_COLUMNS } from './TripTable';

interface TripPersonColumns {
  ID: string;
  NAME: string;
  TRIP_ID: string;
}

export const TRIP_PERSON_COLUMNS: TripPersonColumns = {
  ID: 'id',
  NAME: 'name',
  TRIP_ID: 'trip_id'
}

export const tripPersonTable: RdbTable = {
  tableName: 'TripPerson',
  createQuery: `
    CREATE TABLE "TripPerson" (
      ${TRIP_PERSON_COLUMNS.ID}	INTEGER NOT NULL,
      ${TRIP_PERSON_COLUMNS.NAME}	TEXT NOT NULL,
      ${TRIP_PERSON_COLUMNS.TRIP_ID}	INTEGER NOT NULL,
      PRIMARY KEY(${TRIP_PERSON_COLUMNS.ID} AUTOINCREMENT),
      FOREIGN KEY(${TRIP_PERSON_COLUMNS.TRIP_ID}) REFERENCES "Trip"(${TRIP_COLUMNS.ID}) ON DELETE CASCADE
    );
  `
};
