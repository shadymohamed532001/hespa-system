import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';

export class ReconcileDto {
  @IsIn(['treasury', 'account', 'wallet', 'machine'])
  assetType: 'treasury' | 'account' | 'wallet' | 'machine';

  @ValidateIf((dto: ReconcileDto) => dto.assetType !== 'treasury')
  @IsUUID()
  assetId?: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  countedBalance: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

export class CloseDayDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}
