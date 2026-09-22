import { CollectionsService } from './collections.service.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';
type UserRequest = {
    user: {
        username: string;
    };
};
export declare class CollectionsController {
    private readonly collections;
    constructor(collections: CollectionsService);
    findAll(): Promise<import("../database/entities/collection.entity.js").Collection[]>;
    receive(dto: ReceiveCollectionDto, request: UserRequest): Promise<{
        reference: string;
        agentName: string;
        companyName: string;
        amount: number;
        executionMode: import("../database/enums.js").ExecutionMode;
        status: import("../database/enums.js").CollectionStatus;
        receivedAt: Date;
        executedAt: Date | null;
        account: import("../database/entities/financial-account.entity.js").FinancialAccount | null;
        commission: number;
    } & import("../database/entities/collection.entity.js").Collection>;
    execute(id: string, dto: ExecuteHoldDto, request: UserRequest): Promise<import("../database/entities/collection.entity.js").Collection>;
}
export {};
