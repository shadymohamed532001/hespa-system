import { UsersService } from '../users/users.service.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';
import { TreasuryService } from './treasury.service.js';
type UserRequest = {
    user: {
        userId: string;
        username: string;
    };
};
export declare class TreasuryController {
    private readonly treasury;
    private readonly users;
    constructor(treasury: TreasuryService, users: UsersService);
    summary(): Promise<{
        actualBalance: number;
        pendingAmount: number;
        availableBalance: number;
    }>;
    transfer(dto: InternalTransferDto, request: UserRequest): Promise<{
        from: string;
        to: string;
        amount: number;
    }>;
    rollover(request: UserRequest): Promise<{
        rolledOver: boolean;
        alreadyRolledOver: boolean;
        day: string;
        accounts?: undefined;
        wallets?: undefined;
    } | {
        rolledOver: boolean;
        accounts: number;
        wallets: number;
        alreadyRolledOver?: undefined;
        day?: undefined;
    }>;
}
export {};
