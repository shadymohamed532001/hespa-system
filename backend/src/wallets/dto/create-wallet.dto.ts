import { IsIn, IsNumber, IsOptional, IsString, MaxLength, Min, MinLength } from 'class-validator';

export class CreateWalletDto {
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  name: string;

  @IsIn(['wallet', 'instapay'])
  type: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  openingBalance = 0;
}
