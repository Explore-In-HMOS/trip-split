export interface PersonExpense {
  id: number;
  personId: number;
  participantsIds: number[];
  amount: number;
  details: string;
  createdAt: string;
}