export interface Debt {
  fromPersonId: number;
  toPersonId: number;
  balance: number;
}

export interface Payment {
  fromPersonId: number;
  paidAmount: number;
  spentAmount: number;
}

export interface Trip {
  id: number,
  name: string;
  currency: string;
  createdAt: string;
  finishedAt?: string;
  totalAmount?: number,
  paymentsPerPerson?: Payment[],
  debts?: Debt[]
}