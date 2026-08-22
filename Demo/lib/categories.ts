import { Category } from './types';
import { GRADIENTS } from './theme';

export interface CatMeta {
  key: Category;
  labelKey: string;
  icon: string;
  gradient: keyof typeof GRADIENTS;
}

export const CATEGORIES: CatMeta[] = [
  { key: 'tourist', labelKey: 'popular', icon: 'business', gradient: 'saffron' },
  { key: 'culture', labelKey: 'culture', icon: 'flower', gradient: 'saffron' },
  { key: 'food', labelKey: 'food', icon: 'fast-food', gradient: 'sunset' },
  { key: 'market', labelKey: 'markets', icon: 'cart', gradient: 'sunset' },
  { key: 'nature', labelKey: 'nature2', icon: 'leaf', gradient: 'forest' },
  { key: 'hidden', labelKey: 'hidden2', icon: 'compass', gradient: 'plum' },
];

export function getCatMeta(cat: Category): CatMeta {
  return CATEGORIES.find((c) => c.key === cat) || CATEGORIES[0];
}
