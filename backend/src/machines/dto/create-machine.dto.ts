import { IsNumber, IsString, MaxLength, Min } from 'class-validator';

export class CreateMachineDto {
  @IsString()
  @MaxLength(150)
  name: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  openingBalance: number;
}
