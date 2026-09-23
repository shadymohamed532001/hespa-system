import { UsersService } from '../users/users.service.js';
import { CollectionsService } from './collections.service.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';
import { ReversalDto } from '../common/dto/reversal.dto.js';
type UserRequest = {
    user: {
        userId: string;
        username: string;
    };
};
export declare class CollectionsController {
    private readonly collections;
    private readonly users;
    constructor(collections: CollectionsService, users: UsersService);
    findAll(): Promise<import("../database/entities/collection.entity.js").Collection[]>;
    receive(dto: ReceiveCollectionDto, request: UserRequest): Promise<{
        reference: string;
        agentName: string;
        companyName: string;
        amount: number;
        executionMode: import("../database/enums.js").ExecutionMode;
        status: import("../database/enums.js").CollectionStatus.PENDING | import("../database/enums.js").CollectionStatus.DONE;
        receivedAt: Date;
        executedAt: Date | null;
        account: import("../database/entities/financial-account.entity.js").FinancialAccount | null;
        commission: number;
    } & import("../database/entities/collection.entity.js").Collection>;
    execute(id: string, dto: ExecuteHoldDto, request: UserRequest): Promise<import("../database/entities/collection.entity.js").Collection>;
    reverse(id: string, dto: ReversalDto, request: UserRequest): Promise<{
        reversed: boolean;
        collectionId: string;
        reference: string;
        reason: string;
    }>;
}
export {};
