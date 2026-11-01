import { z } from '../../docs/registry';

const password = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(128)
  .regex(/[A-Za-z]/, 'Password must contain a letter')
  .regex(/\d/, 'Password must contain a digit');

export const RegisterBody = z
  .object({
    email: z.string().trim().toLowerCase().email().max(254),
    password,
    fullNameAr: z.string().trim().min(2).max(120).openapi({ example: 'مصطفى وحدان' }),
    fullNameEn: z.string().trim().min(2).max(120).openapi({ example: 'Mostafa Wahdaan' }),
  })
  .strict()
  .openapi('RegisterRequest');

export const LoginBody = z
  .object({
    email: z.string().trim().toLowerCase().email(),
    password: z.string().min(1).max(128),
  })
  .strict()
  .openapi('LoginRequest');

export const RefreshBody = z.object({ refreshToken: z.string().min(20).max(200) }).strict().openapi('RefreshRequest');

export const ChangePasswordBody = z
  .object({
    oldPassword: z.string().min(1).max(128),
    newPassword: password,
    confirmPassword: z.string(),
  })
  .strict()
  .refine((b) => b.newPassword === b.confirmPassword, { message: 'Passwords do not match', path: ['confirmPassword'] })
  .refine((b) => b.newPassword !== b.oldPassword, { message: 'New password must differ from the old one', path: ['newPassword'] })
  .openapi('ChangePasswordRequest');

export const UserDto = z
  .object({
    id: z.string().uuid(),
    email: z.string(),
    fullNameAr: z.string(),
    fullNameEn: z.string(),
    unifiedId: z.string().openapi({ example: 'EGX-100001' }),
    role: z.enum(['TRADER', 'ADMIN']),
    createdAt: z.string(),
  })
  .openapi('User');

export const AuthResponse = z
  .object({
    user: UserDto,
    accessToken: z.string(),
    refreshToken: z.string(),
    tokenType: z.literal('Bearer'),
    expiresIn: z.number().openapi({ description: 'Access token lifetime in seconds' }),
  })
  .openapi('AuthResponse');
