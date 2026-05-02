import { PersonExpense } from './PersonExpense';
import { TripPerson } from './TripPerson';

export interface ExpenseAndPersons {
  expense: PersonExpense;
  persons: TripPerson[];
  currency: string;
}