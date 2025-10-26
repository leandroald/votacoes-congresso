import * as React from 'react';
import { cn } from '@/lib/utils';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'ghost';
  size?: 'sm' | 'md';
}

export function Button({ className, variant = 'default', size = 'md', ...props }: ButtonProps) {
  const base = 'inline-flex items-center justify-center rounded-md font-medium transition outline-none';
  const variants = {
    default: 'bg-black text-white hover:opacity-90',
    ghost: 'bg-transparent hover:bg-black/5',
  };
  const sizes = {
    sm: 'h-8 px-3 text-sm',
    md: 'h-10 px-4',
  };
  return (
    <button className={cn(base, variants[variant], sizes[size], className)} {...props} />
  );
}
