import {createHash} from 'crypto';
export const SCALE = 1000;
export function id(value: unknown, label = 'id'): string {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw new Error(`${label} inválido`);
  return value;
}
export function decimalUnits(value: unknown, scale: number, round = false): number {
  if (typeof value !== 'number' && typeof value !== 'string') throw new Error('Valor inválido');
  const text = String(value);
  if (!/^-?\d+(\.\d+)?$/.test(text)) throw new Error('Decimal inválido');
  const negative = text.startsWith('-');
  const [whole, fraction = ''] = text.replace('-', '').split('.');
  const digits = Math.log10(scale);
  const kept = (fraction + '0'.repeat(digits)).slice(0, digits);
  if (!round && /[1-9]/.test(fraction.slice(digits))) throw new Error('Precisão excedida');
  let units = Number(whole) * scale + Number(kept);
  if (round && Number(fraction[digits] || 0) >= 5) units++;
  units *= negative ? -1 : 1;
  if (!Number.isSafeInteger(units)) throw new Error('Valor fora do limite');
  return units;
}
export function canonical(value: any): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`;
  return JSON.stringify(value);
}
export const hash = (value: any) => createHash('sha256').update(canonical(value)).digest('hex');
export const moduleName = (value: string) => ({rdo: 'diario', almoxarifado: 'estoque'}[value] || value);
export function active(data: any): boolean { return data?.isActive === true; }
export function manager(data: any): boolean { return active(data) && (data.isAdmin === true || data.isOwner === true); }
