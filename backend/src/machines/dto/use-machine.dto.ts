import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class UseMachineDto {
  @IsIn([
    'mobile_credit',
    'mobile_package',
    'landline_internet',
    'landline_phone',
    'other',
  ])
  serviceType:
    | 'mobile_credit'
    | 'mobile_package'
    | 'landline_internet'
    | 'landline_phone'
    | 'other';

  @IsString()
  @MaxLength(80)
  customerNumber: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  commission: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;
}
