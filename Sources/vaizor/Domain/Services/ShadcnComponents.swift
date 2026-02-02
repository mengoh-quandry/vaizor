import Foundation

/// Bundled shadcn/ui-style components as JavaScript globals for artifact rendering
/// These components work without imports - they're pre-loaded as globals
struct ShadcnComponents {

    /// JavaScript code that defines all UI components as globals
    static let componentDefinitions = """
    // ============================================
    // Vaizor UI Components (shadcn/ui-style)
    // All components available as globals - no imports needed
    // ============================================

    // Utility: cn() for className merging
    window.cn = function(...classes) {
        return classes.filter(Boolean).join(' ');
    };

    // ============================================
    // BUTTON
    // ============================================
    window.Button = function({ children, variant = 'default', size = 'default', className = '', disabled = false, onClick, ...props }) {
        const baseStyles = 'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50';

        const variants = {
            default: 'bg-slate-900 text-white hover:bg-slate-800 dark:bg-slate-50 dark:text-slate-900 dark:hover:bg-slate-200',
            destructive: 'bg-red-500 text-white hover:bg-red-600 dark:bg-red-600 dark:hover:bg-red-700',
            outline: 'border border-slate-200 bg-transparent hover:bg-slate-100 dark:border-slate-700 dark:hover:bg-slate-800',
            secondary: 'bg-slate-100 text-slate-900 hover:bg-slate-200 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700',
            ghost: 'hover:bg-slate-100 dark:hover:bg-slate-800',
            link: 'text-slate-900 underline-offset-4 hover:underline dark:text-slate-100',
        };

        const sizes = {
            default: 'h-10 px-4 py-2',
            sm: 'h-9 rounded-md px-3',
            lg: 'h-11 rounded-md px-8',
            icon: 'h-10 w-10',
        };

        return React.createElement('button', {
            className: cn(baseStyles, variants[variant], sizes[size], className),
            disabled,
            onClick,
            ...props
        }, children);
    };

    // ============================================
    // CARD
    // ============================================
    window.Card = function({ children, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('rounded-xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-950', className),
            ...props
        }, children);
    };

    window.CardHeader = function({ children, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('flex flex-col space-y-1.5 p-6', className),
            ...props
        }, children);
    };

    window.CardTitle = function({ children, className = '', ...props }) {
        return React.createElement('h3', {
            className: cn('text-2xl font-semibold leading-none tracking-tight', className),
            ...props
        }, children);
    };

    window.CardDescription = function({ children, className = '', ...props }) {
        return React.createElement('p', {
            className: cn('text-sm text-slate-500 dark:text-slate-400', className),
            ...props
        }, children);
    };

    window.CardContent = function({ children, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('p-6 pt-0', className),
            ...props
        }, children);
    };

    window.CardFooter = function({ children, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('flex items-center p-6 pt-0', className),
            ...props
        }, children);
    };

    // ============================================
    // BADGE
    // ============================================
    window.Badge = function({ children, variant = 'default', className = '', ...props }) {
        const variants = {
            default: 'bg-slate-900 text-white dark:bg-slate-50 dark:text-slate-900',
            secondary: 'bg-slate-100 text-slate-900 dark:bg-slate-800 dark:text-slate-100',
            destructive: 'bg-red-500 text-white',
            outline: 'border border-slate-200 dark:border-slate-700',
            success: 'bg-emerald-500 text-white',
            warning: 'bg-amber-500 text-white',
        };

        return React.createElement('div', {
            className: cn('inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors', variants[variant], className),
            ...props
        }, children);
    };

    // ============================================
    // INPUT
    // ============================================
    window.Input = function({ className = '', type = 'text', ...props }) {
        return React.createElement('input', {
            type,
            className: cn(
                'flex h-10 w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm',
                'placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-400',
                'disabled:cursor-not-allowed disabled:opacity-50',
                'dark:border-slate-700 dark:bg-slate-950 dark:placeholder:text-slate-400',
                className
            ),
            ...props
        });
    };

    // ============================================
    // LABEL
    // ============================================
    window.Label = function({ children, className = '', htmlFor, ...props }) {
        return React.createElement('label', {
            htmlFor,
            className: cn('text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70', className),
            ...props
        }, children);
    };

    // ============================================
    // TEXTAREA
    // ============================================
    window.Textarea = function({ className = '', ...props }) {
        return React.createElement('textarea', {
            className: cn(
                'flex min-h-[80px] w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm',
                'placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-400',
                'disabled:cursor-not-allowed disabled:opacity-50',
                'dark:border-slate-700 dark:bg-slate-950',
                className
            ),
            ...props
        });
    };

    // ============================================
    // SEPARATOR
    // ============================================
    window.Separator = function({ orientation = 'horizontal', className = '', ...props }) {
        return React.createElement('div', {
            className: cn(
                'shrink-0 bg-slate-200 dark:bg-slate-700',
                orientation === 'horizontal' ? 'h-[1px] w-full' : 'h-full w-[1px]',
                className
            ),
            ...props
        });
    };

    // ============================================
    // PROGRESS
    // ============================================
    window.Progress = function({ value = 0, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('relative h-4 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-800', className),
            ...props
        },
            React.createElement('div', {
                className: 'h-full bg-slate-900 transition-all dark:bg-slate-50',
                style: { width: value + '%' }
            })
        );
    };

    // ============================================
    // SKELETON
    // ============================================
    window.Skeleton = function({ className = '', ...props }) {
        return React.createElement('div', {
            className: cn('animate-pulse rounded-md bg-slate-200 dark:bg-slate-800', className),
            ...props
        });
    };

    // ============================================
    // AVATAR
    // ============================================
    window.Avatar = function({ children, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('relative flex h-10 w-10 shrink-0 overflow-hidden rounded-full', className),
            ...props
        }, children);
    };

    window.AvatarImage = function({ src, alt = '', className = '', ...props }) {
        return React.createElement('img', {
            src,
            alt,
            className: cn('aspect-square h-full w-full', className),
            ...props
        });
    };

    window.AvatarFallback = function({ children, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('flex h-full w-full items-center justify-center rounded-full bg-slate-100 dark:bg-slate-800', className),
            ...props
        }, children);
    };

    // ============================================
    // ALERT
    // ============================================
    window.Alert = function({ children, variant = 'default', className = '', ...props }) {
        const variants = {
            default: 'bg-white text-slate-900 border-slate-200 dark:bg-slate-950 dark:text-slate-100 dark:border-slate-800',
            destructive: 'bg-red-50 text-red-900 border-red-200 dark:bg-red-950 dark:text-red-100 dark:border-red-800',
            success: 'bg-emerald-50 text-emerald-900 border-emerald-200 dark:bg-emerald-950 dark:text-emerald-100',
            warning: 'bg-amber-50 text-amber-900 border-amber-200 dark:bg-amber-950 dark:text-amber-100',
        };

        return React.createElement('div', {
            className: cn('relative w-full rounded-lg border p-4', variants[variant], className),
            role: 'alert',
            ...props
        }, children);
    };

    window.AlertTitle = function({ children, className = '', ...props }) {
        return React.createElement('h5', {
            className: cn('mb-1 font-medium leading-none tracking-tight', className),
            ...props
        }, children);
    };

    window.AlertDescription = function({ children, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('text-sm [&_p]:leading-relaxed', className),
            ...props
        }, children);
    };

    // ============================================
    // TABS (Simple version)
    // ============================================
    window.Tabs = function({ children, defaultValue, value, onValueChange, className = '', ...props }) {
        const [activeTab, setActiveTab] = React.useState(value || defaultValue);

        React.useEffect(() => {
            if (value !== undefined) setActiveTab(value);
        }, [value]);

        const handleChange = (newValue) => {
            setActiveTab(newValue);
            if (onValueChange) onValueChange(newValue);
        };

        return React.createElement('div', {
            className: cn('w-full', className),
            ...props
        }, React.Children.map(children, child => {
            if (!React.isValidElement(child)) return child;
            return React.cloneElement(child, { activeTab, onTabChange: handleChange });
        }));
    };

    window.TabsList = function({ children, className = '', activeTab, onTabChange, ...props }) {
        return React.createElement('div', {
            className: cn('inline-flex h-10 items-center justify-center rounded-md bg-slate-100 p-1 text-slate-500 dark:bg-slate-800 dark:text-slate-400', className),
            ...props
        }, React.Children.map(children, child => {
            if (!React.isValidElement(child)) return child;
            return React.cloneElement(child, { activeTab, onTabChange });
        }));
    };

    window.TabsTrigger = function({ children, value, className = '', activeTab, onTabChange, ...props }) {
        const isActive = activeTab === value;
        return React.createElement('button', {
            className: cn(
                'inline-flex items-center justify-center whitespace-nowrap rounded-sm px-3 py-1.5 text-sm font-medium transition-all',
                isActive ? 'bg-white text-slate-900 shadow-sm dark:bg-slate-950 dark:text-slate-100' : '',
                className
            ),
            onClick: () => onTabChange && onTabChange(value),
            ...props
        }, children);
    };

    window.TabsContent = function({ children, value, className = '', activeTab, ...props }) {
        if (activeTab !== value) return null;
        return React.createElement('div', {
            className: cn('mt-2', className),
            ...props
        }, children);
    };

    // ============================================
    // SWITCH
    // ============================================
    window.Switch = function({ checked = false, onCheckedChange, className = '', disabled = false, ...props }) {
        return React.createElement('button', {
            role: 'switch',
            'aria-checked': checked,
            disabled,
            className: cn(
                'peer inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors',
                'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-400 focus-visible:ring-offset-2',
                'disabled:cursor-not-allowed disabled:opacity-50',
                checked ? 'bg-slate-900 dark:bg-slate-50' : 'bg-slate-200 dark:bg-slate-700',
                className
            ),
            onClick: () => !disabled && onCheckedChange && onCheckedChange(!checked),
            ...props
        },
            React.createElement('span', {
                className: cn(
                    'pointer-events-none block h-5 w-5 rounded-full bg-white shadow-lg ring-0 transition-transform dark:bg-slate-900',
                    checked ? 'translate-x-5' : 'translate-x-0'
                )
            })
        );
    };

    // ============================================
    // TABLE
    // ============================================
    window.Table = function({ children, className = '', ...props }) {
        return React.createElement('div', { className: 'relative w-full overflow-auto' },
            React.createElement('table', {
                className: cn('w-full caption-bottom text-sm', className),
                ...props
            }, children)
        );
    };

    window.TableHeader = function({ children, className = '', ...props }) {
        return React.createElement('thead', {
            className: cn('[&_tr]:border-b', className),
            ...props
        }, children);
    };

    window.TableBody = function({ children, className = '', ...props }) {
        return React.createElement('tbody', {
            className: cn('[&_tr:last-child]:border-0', className),
            ...props
        }, children);
    };

    window.TableRow = function({ children, className = '', ...props }) {
        return React.createElement('tr', {
            className: cn('border-b border-slate-200 transition-colors hover:bg-slate-50 dark:border-slate-700 dark:hover:bg-slate-800/50', className),
            ...props
        }, children);
    };

    window.TableHead = function({ children, className = '', ...props }) {
        return React.createElement('th', {
            className: cn('h-12 px-4 text-left align-middle font-medium text-slate-500 dark:text-slate-400', className),
            ...props
        }, children);
    };

    window.TableCell = function({ children, className = '', ...props }) {
        return React.createElement('td', {
            className: cn('p-4 align-middle', className),
            ...props
        }, children);
    };

    // ============================================
    // SCROLL AREA (Simple version)
    // ============================================
    window.ScrollArea = function({ children, className = '', ...props }) {
        return React.createElement('div', {
            className: cn('relative overflow-auto', className),
            ...props
        }, children);
    };

    // ============================================
    // TOOLTIP (Simple CSS version)
    // ============================================
    window.Tooltip = function({ children, content, className = '', ...props }) {
        const [show, setShow] = React.useState(false);
        return React.createElement('div', {
            className: 'relative inline-block',
            onMouseEnter: () => setShow(true),
            onMouseLeave: () => setShow(false),
            ...props
        },
            children,
            show && React.createElement('div', {
                className: cn(
                    'absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-1.5 text-xs',
                    'bg-slate-900 text-white rounded-md shadow-md whitespace-nowrap z-50',
                    'dark:bg-slate-50 dark:text-slate-900',
                    className
                )
            }, content)
        );
    };

    console.log('[Vaizor] UI Components loaded: Button, Card, Badge, Input, Label, Textarea, Separator, Progress, Skeleton, Avatar, Alert, Tabs, Switch, Table, ScrollArea, Tooltip');
    """

    /// CSS for component styling enhancements
    static let componentCSS = """
    /* Animation for Skeleton */
    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
    }
    .animate-pulse {
        animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
    }

    /* Focus ring utilities */
    .focus-visible\\:ring-2:focus-visible {
        --tw-ring-offset-shadow: var(--tw-ring-inset) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color);
        --tw-ring-shadow: var(--tw-ring-inset) 0 0 0 calc(2px + var(--tw-ring-offset-width)) var(--tw-ring-color);
        box-shadow: var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow, 0 0 #0000);
    }
    """
}
