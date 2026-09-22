import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';
import { WalletsService } from './wallets.service.js';
type UserRequest = {
    user: {
        username: string;
    };
};
export declare class WalletsController {
    private readonly wallets;
    constructor(wallets: WalletsService);
    findAll(): Promise<import("../database/entities/wallet.entity.js").Wallet[]>;
    create(dto: CreateWalletDto): Promise<import("../database/entities/wallet.entity.js").Wallet>;
    topUp(id: string, dto: TopUpWalletDto, request: UserRequest): Promise<import("../database/entities/wallet.entity.js").Wallet>;
}
export {};
