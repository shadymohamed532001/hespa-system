import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { Wallet } from '../database/entities/wallet.entity.js';
import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';
export declare const WALLET_DAILY_TOP_UP_LIMIT = 60000;
export declare const WALLET_MONTHLY_TOP_UP_LIMIT = 200000;
export declare class WalletsService implements OnModuleInit {
    private readonly wallets;
    private readonly dataSource;
    private readonly config;
    constructor(wallets: Repository<Wallet>, dataSource: DataSource, config: ConfigService);
    onModuleInit(): Promise<void>;
    findAll(): Promise<Wallet[]>;
    create(dto: CreateWalletDto, username: string): Promise<Wallet>;
    topUp(id: string, dto: TopUpWalletDto, username: string): Promise<Wallet>;
}
