import { IsIn, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min, ValidateIf } from 'class-validator';

const assetTypes = ['treasury', 'account', 'wallet', 'machine'] as const;

export class InternalTransferDto {
  @IsIn(assetTypes)
  fromType: (typeof assetTypes)[number];

  @ValidateIf((value: InternalTransferDto) => value.fromType !== 'treasury')
  @IsUUID()
  fromId?: string;

  @IsIn(assetTypes)
  toType: (typeof assetTypes)[number];

  @ValidateIf((value: InternalTransferDto) => value.toType !== 'treasury')
  @IsUUID()
  toId?: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;
}
