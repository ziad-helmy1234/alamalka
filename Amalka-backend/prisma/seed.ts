/**
 * Seed data.
 * ⚠️ Stock prices, P/E ratios, 52-week ranges and Sharia flags below are SAMPLE values for
 * development only — replace them from your licensed market-data feed and your Sharia board's list.
 */
import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { PrismaClient, type Currency } from '@prisma/client';

const prisma = new PrismaClient();

type S = [symbol: string, nameEn: string, nameAr: string, sectorEn: string, sectorAr: string, price: number, pe: number | null, sharia: boolean, currency?: Currency];

const SECTORS = {
  banks: ['Banks', 'البنوك'],
  realEstate: ['Real Estate', 'العقارات'],
  basic: ['Basic Resources', 'الموارد الأساسية'],
  industrial: ['Industrial Goods & Services', 'الخدمات والمنتجات الصناعية'],
  telecom: ['IT, Media & Telecom', 'الاتصالات والإعلام وتكنولوجيا المعلومات'],
  food: ['Food, Beverages & Tobacco', 'الأغذية والمشروبات والتبغ'],
  financial: ['Non-bank Financial Services', 'الخدمات المالية غير المصرفية'],
  health: ['Healthcare & Pharmaceuticals', 'الرعاية الصحية والأدوية'],
  energy: ['Energy & Support Services', 'الطاقة والخدمات المساندة'],
  chemicals: ['Building Materials & Chemicals', 'مواد البناء والكيماويات'],
  textiles: ['Textile & Durables', 'المنسوجات والسلع المعمرة'],
} as const;

const sec = (k: keyof typeof SECTORS) => SECTORS[k];

const STOCKS: S[] = [
  ['COMI', 'Commercial International Bank', 'البنك التجاري الدولي', ...sec('banks'), 82.5, 6.1, false],
  ['CIEB', 'Credit Agricole Egypt', 'كريدي أجريكول مصر', ...sec('banks'), 21.4, 4.8, false],
  ['ADIB', 'Abu Dhabi Islamic Bank Egypt', 'مصرف أبوظبي الإسلامي - مصر', ...sec('banks'), 34.9, 3.9, true],
  ['TMGH', 'Talaat Moustafa Group Holding', 'مجموعة طلعت مصطفى القابضة', ...sec('realEstate'), 58.2, 11.3, true],
  ['PHDC', 'Palm Hills Developments', 'بالم هيلز للتعمير', ...sec('realEstate'), 7.35, 6.7, true],
  ['HELI', 'Heliopolis Housing & Development', 'مصر الجديدة للإسكان والتعمير', ...sec('realEstate'), 9.8, 8.4, true],
  ['ESRS', 'Ezz Steel', 'حديد عز', ...sec('basic'), 97.1, 5.5, true],
  ['ABUK', 'Abu Qir Fertilizers', 'أبوقير للأسمدة', ...sec('chemicals'), 55.6, 6.9, true],
  ['MFPC', 'Misr Fertilizers Production (MOPCO)', 'مصر لإنتاج الأسمدة - موبكو', ...sec('chemicals'), 38.7, 5.2, true],
  ['SWDY', 'Elsewedy Electric', 'السويدي إليكتريك', ...sec('industrial'), 76.9, 9.6, true],
  ['ETEL', 'Telecom Egypt', 'المصرية للاتصالات', ...sec('telecom'), 39.2, 5.9, false],
  ['FWRY', 'Fawry for Banking Technology', 'فوري لتكنولوجيا البنوك', ...sec('telecom'), 9.6, 18.2, true],
  ['EFIH', 'e-finance for Digital & Financial Investments', 'إي فاينانس للاستثمارات المالية والرقمية', ...sec('telecom'), 19.3, 21.4, true],
  ['EAST', 'Eastern Company', 'الشرقية - إيسترن كومباني', ...sec('food'), 30.1, 7.8, false],
  ['JUFO', 'Juhayna Food Industries', 'جهينة للصناعات الغذائية', ...sec('food'), 22.8, 10.5, true],
  ['HRHO', 'EFG Holding', 'إي إف جي القابضة', ...sec('financial'), 24.6, 7.1, false],
  ['CLHO', 'Cleopatra Hospital Group', 'مجموعة مستشفيات كليوباترا', ...sec('health'), 7.9, 14.6, true],
  ['AMOC', 'Alexandria Mineral Oils', 'الإسكندرية للزيوت المعدنية', ...sec('energy'), 8.45, 6.3, true],
  ['ORWE', 'Oriental Weavers', 'السجاد الشرقي - أوريانتال ويفرز', ...sec('textiles'), 24.1, 6.8, true],
  ['EKHO', 'Egypt Kuwait Holding (USD)', 'القابضة المصرية الكويتية (دولار)', ...sec('financial'), 0.985, 7.4, false, 'USD'],
];

async function seedStocks() {
  for (const [symbol, nameEn, nameAr, sectorEn, sectorAr, price, pe, sharia, currency = 'EGP'] of STOCKS) {
    const p = price.toFixed(price < 1 ? 3 : 2);
    const data = {
      nameEn, nameAr, sectorEn, sectorAr,
      currentPrice: p, previousClose: p, openPrice: p, dayHigh: p, dayLow: p,
      volume: 0n,
      isShariaCompliant: sharia,
      currency,
      peRatio: pe,
      week52High: (price * 1.32).toFixed(price < 1 ? 3 : 2),
      week52Low: (price * 0.71).toFixed(price < 1 ? 3 : 2),
    };
    await prisma.stock.upsert({ where: { symbol }, create: { symbol, ...data }, update: { nameEn, nameAr, sectorEn, sectorAr, isShariaCompliant: sharia, peRatio: pe } });
  }
  console.log(`✔ ${STOCKS.length} stocks`);
}

async function seedUser(email: string, password: string, nameEn: string, nameAr: string, role: 'TRADER' | 'ADMIN', funds: { EGP: number; USD: number }) {
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) return console.log(`• ${email} already exists`);
  const user = await prisma.user.create({
    data: {
      email, role, fullNameEn: nameEn, fullNameAr: nameAr,
      passwordHash: await bcrypt.hash(password, 12),
      portfolios: { create: [{ currency: 'EGP' }, { currency: 'USD' }] },
    },
    include: { portfolios: true },
  });
  for (const p of user.portfolios) {
    const amount = funds[p.currency];
    if (amount <= 0) continue;
    // Fund via a completed MANUAL transfer + ledger entry so the books always reconcile.
    const t = await prisma.transfer.create({
      data: { userId: user.id, portfolioId: p.id, amount, currency: p.currency, type: 'DEPOSIT', method: 'Bank Transfer', provider: 'MANUAL', status: 'COMPLETED' },
    });
    const w = await prisma.portfolio.update({ where: { id: p.id }, data: { cashBalance: amount, buyingPower: amount } });
    await prisma.ledgerEntry.create({
      data: { portfolioId: p.id, type: 'DEPOSIT', cashDelta: amount, buyingPowerDelta: amount, cashBalanceAfter: w.cashBalance, refId: t.id },
    });
  }
  console.log(`✔ ${role.toLowerCase()} ${email} (${user.unifiedId})`);
}

async function main() {
  await seedStocks();
  if (process.env.NODE_ENV === 'production') {
    console.log('Production: skipping demo users.');
    return;
  }
  await seedUser('demo@amalka.app', 'Demo12345', 'Demo Trader', 'متداول تجريبي', 'TRADER', { EGP: 250_000, USD: 10_000 });
  await seedUser('admin@amalka.app', 'Admin12345', 'Amalka Admin', 'مدير أملكا', 'ADMIN', { EGP: 0, USD: 0 });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
