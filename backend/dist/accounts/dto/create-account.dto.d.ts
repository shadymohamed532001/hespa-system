import { AccountType } from '../../database/enums.js';
export declare class CreateAccountDto {
    name: string;
    type: AccountType;
    openingBalance: number;
}
