declare const assetTypes: readonly ["treasury", "account", "wallet", "machine"];
export declare class InternalTransferDto {
    fromType: (typeof assetTypes)[number];
    fromId?: string;
    toType: (typeof assetTypes)[number];
    toId?: string;
    amount: number;
    reference?: string;
}
export {};
