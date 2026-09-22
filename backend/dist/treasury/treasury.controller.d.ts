import { InternalTransferDto } from './dto/internal-transfer.dto.js';
import { TreasuryService } from './treasury.service.js';
type UserRequest = {
    user: {
        username: string;
    };
};
export declare class TreasuryController {
    private readonly treasury;
    constructor(treasury: TreasuryService);
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
        accounts: number;
        wallets: number;
    }>;
}
export {};
