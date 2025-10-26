import * as React from 'react';
import { cn } from '@/lib/utils';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        'h-10 w-full rounded-md border px-3 text-sm outline-none',
        'border-gray-300 focus:ring-2 focus:ring-black/20',
        className
      )}
      {...props}
    />
  )
);
Input.displayName = 'Input';
