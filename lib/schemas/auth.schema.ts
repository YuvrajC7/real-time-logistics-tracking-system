import { z } from 'zod'

export const loginSchema = z.object({
  email:    z.string().email('Valid email required'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
})

export const signupSchema = z.object({
  full_name: z.string().min(2, 'Full name required'),
  email:     z.string().email('Valid email required'),
  password:  z.string().min(8, 'At least 8 characters'),
  confirm:   z.string(),
}).refine(d => d.password === d.confirm, {
  message: 'Passwords do not match',
  path: ['confirm'],
})

export const resetSchema = z.object({
  email: z.string().email('Valid email required'),
})

export type LoginForm = z.infer<typeof loginSchema>
export type SignupForm = z.infer<typeof signupSchema>
export type ResetForm  = z.infer<typeof resetSchema>
