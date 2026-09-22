import { IsEnum, IsNumber, IsString, MaxLength, Min, MinLength } from 'class-validator';
import { InventoryCategory } from '../../database/enums.js';

export class CreateInventoryProductDto {
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  name: string;

  @IsEnum(InventoryCategory)
  category: InventoryCategory;

  @IsNumber({ maxDecimalPlaces: 0 })
  @Min(0)
  openingStock: number;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  defaultPrice: number;
}
