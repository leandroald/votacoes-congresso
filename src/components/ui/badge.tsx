import * as React from 'react';
import { cn } from '@/lib/utils';

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: 'secondary' | 'outline';
}

export function Badge({ className, variant = 'secondary', ...props }: BadgeProps) {
  const variants = {
    secondary: 'bg-gray-100 text-gray-900',
    outline: 'border border-gray-300',
  };
  return (
    <span className={cn('inline-flex items-center rounded px-2 py-0.5 text-xs', variants[variant], className)} {...props} />
  );
}
