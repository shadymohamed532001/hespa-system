import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateWalletDto {
  @IsString()
  name: string;

  @IsString()
  type: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  openingBalance = 0;
}

