import Foundation

/// High-quality React component templates for artifact creation
/// These templates use the Vaizor design system and shadcn/ui-style components
struct ArtifactTemplates {

    /// Template category for organization
    enum Category: String, CaseIterable {
        case dashboard = "Dashboard"
        case charts = "Charts & Data"
        case forms = "Forms"
        case cards = "Cards & Layouts"
        case interactive = "Interactive"
        case marketing = "Marketing"
        case commerce = "Commerce"
        case analytics = "Analytics"
    }

    /// A template definition
    struct Template: Identifiable {
        let id: String
        let name: String
        let description: String
        let category: Category
        let code: String
        let previewImageName: String?

        init(id: String, name: String, description: String, category: Category, code: String, previewImageName: String? = nil) {
            self.id = id
            self.name = name
            self.description = description
            self.category = category
            self.code = code
            self.previewImageName = previewImageName
        }
    }

    /// All available templates
    static let all: [Template] = [
        // MARK: - Dashboard Templates

        Template(
            id: "dashboard-stats",
            name: "Stats Dashboard",
            description: "Clean stats cards with trends and metrics",
            category: .dashboard,
            code: """
            function StatsDashboard() {
                const stats = [
                    { label: 'Total Revenue', value: '$45,231.89', change: '+20.1%', trend: 'up' },
                    { label: 'Subscriptions', value: '+2,350', change: '+180.1%', trend: 'up' },
                    { label: 'Active Users', value: '12,234', change: '+19%', trend: 'up' },
                    { label: 'Bounce Rate', value: '24.5%', change: '-4.3%', trend: 'down' },
                ];

                return (
                    <div className="p-6 bg-slate-50 dark:bg-slate-900 min-h-screen">
                        <h1 className="text-2xl font-bold mb-6 text-slate-900 dark:text-white">Dashboard</h1>
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                            {stats.map((stat, i) => (
                                <Card key={i} className="p-6">
                                    <div className="flex items-center justify-between">
                                        <span className="text-sm text-slate-500">{stat.label}</span>
                                        <Badge variant={stat.trend === 'up' ? 'success' : 'destructive'}>
                                            {stat.change}
                                        </Badge>
                                    </div>
                                    <div className="mt-2 text-3xl font-bold text-slate-900 dark:text-white">
                                        {stat.value}
                                    </div>
                                </Card>
                            ))}
                        </div>
                    </div>
                );
            }
            """
        ),

        Template(
            id: "dashboard-overview",
            name: "Overview Dashboard",
            description: "Full dashboard with charts, stats, and recent activity",
            category: .dashboard,
            code: """
            function OverviewDashboard() {
                const [activeTab, setActiveTab] = useState('overview');

                const chartData = [
                    { name: 'Jan', value: 4000, visits: 2400 },
                    { name: 'Feb', value: 3000, visits: 1398 },
                    { name: 'Mar', value: 5000, visits: 3800 },
                    { name: 'Apr', value: 4500, visits: 3908 },
                    { name: 'May', value: 6000, visits: 4800 },
                    { name: 'Jun', value: 5500, visits: 3800 },
                ];

                const recentActivity = [
                    { user: 'Alex K.', action: 'Upgraded to Pro', time: '2 min ago' },
                    { user: 'Sarah M.', action: 'Completed onboarding', time: '5 min ago' },
                    { user: 'John D.', action: 'Made a purchase', time: '12 min ago' },
                ];

                return (
                    <div className="p-6 bg-slate-50 dark:bg-slate-900 min-h-screen">
                        <div className="flex items-center justify-between mb-6">
                            <h1 className="text-2xl font-bold text-slate-900 dark:text-white">Overview</h1>
                            <Button variant="default">Download Report</Button>
                        </div>

                        <Tabs defaultValue="overview" className="mb-6">
                            <TabsList>
                                <TabsTrigger value="overview">Overview</TabsTrigger>
                                <TabsTrigger value="analytics">Analytics</TabsTrigger>
                                <TabsTrigger value="reports">Reports</TabsTrigger>
                            </TabsList>
                        </Tabs>

                        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                            <Card className="lg:col-span-2 p-6">
                                <h3 className="text-lg font-semibold mb-4">Revenue Overview</h3>
                                <ResponsiveContainer width="100%" height={300}>
                                    <AreaChart data={chartData}>
                                        <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
                                        <XAxis dataKey="name" stroke="#94a3b8" />
                                        <YAxis stroke="#94a3b8" />
                                        <Tooltip />
                                        <Area type="monotone" dataKey="value" stroke="#635bff" fill="#635bff" fillOpacity={0.2} />
                                        <Area type="monotone" dataKey="visits" stroke="#00d4ff" fill="#00d4ff" fillOpacity={0.2} />
                                    </AreaChart>
                                </ResponsiveContainer>
                            </Card>

                            <Card className="p-6">
                                <h3 className="text-lg font-semibold mb-4">Recent Activity</h3>
                                <div className="space-y-4">
                                    {recentActivity.map((item, i) => (
                                        <div key={i} className="flex items-center gap-3">
                                            <Avatar>
                                                <AvatarFallback>{item.user[0]}</AvatarFallback>
                                            </Avatar>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-sm font-medium truncate">{item.user}</p>
                                                <p className="text-xs text-slate-500">{item.action}</p>
                                            </div>
                                            <span className="text-xs text-slate-400">{item.time}</span>
                                        </div>
                                    ))}
                                </div>
                            </Card>
                        </div>
                    </div>
                );
            }
            """
        ),

        // MARK: - Chart Templates

        Template(
            id: "chart-line",
            name: "Line Chart",
            description: "Responsive line chart with multiple series",
            category: .charts,
            code: """
            function LineChartDemo() {
                const data = [
                    { month: 'Jan', sales: 4000, revenue: 2400, profit: 1200 },
                    { month: 'Feb', sales: 3000, revenue: 1398, profit: 900 },
                    { month: 'Mar', sales: 5000, revenue: 3800, profit: 1900 },
                    { month: 'Apr', sales: 4500, revenue: 3908, profit: 1700 },
                    { month: 'May', sales: 6000, revenue: 4800, profit: 2400 },
                    { month: 'Jun', sales: 5500, revenue: 3800, profit: 1900 },
                    { month: 'Jul', sales: 7000, revenue: 5200, profit: 2800 },
                ];

                return (
                    <Card className="p-6">
                        <CardHeader className="px-0 pt-0">
                            <CardTitle>Performance Metrics</CardTitle>
                            <CardDescription>Monthly sales, revenue, and profit trends</CardDescription>
                        </CardHeader>
                        <CardContent className="px-0 pb-0">
                            <ResponsiveContainer width="100%" height={350}>
                                <LineChart data={data}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
                                    <XAxis dataKey="month" stroke="#94a3b8" />
                                    <YAxis stroke="#94a3b8" />
                                    <Tooltip
                                        contentStyle={{
                                            backgroundColor: '#fff',
                                            border: '1px solid #e2e8f0',
                                            borderRadius: '8px'
                                        }}
                                    />
                                    <Legend />
                                    <Line type="monotone" dataKey="sales" stroke="#635bff" strokeWidth={2} dot={{ fill: '#635bff' }} />
                                    <Line type="monotone" dataKey="revenue" stroke="#00d4ff" strokeWidth={2} dot={{ fill: '#00d4ff' }} />
                                    <Line type="monotone" dataKey="profit" stroke="#10b981" strokeWidth={2} dot={{ fill: '#10b981' }} />
                                </LineChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>
                );
            }
            """
        ),

        Template(
            id: "chart-bar",
            name: "Bar Chart",
            description: "Vertical bar chart with comparison data",
            category: .charts,
            code: """
            function BarChartDemo() {
                const data = [
                    { name: 'Mon', desktop: 186, mobile: 80 },
                    { name: 'Tue', desktop: 305, mobile: 200 },
                    { name: 'Wed', desktop: 237, mobile: 120 },
                    { name: 'Thu', desktop: 273, mobile: 190 },
                    { name: 'Fri', desktop: 209, mobile: 130 },
                    { name: 'Sat', desktop: 214, mobile: 140 },
                    { name: 'Sun', desktop: 192, mobile: 100 },
                ];

                return (
                    <Card className="p-6">
                        <CardHeader className="px-0 pt-0">
                            <CardTitle>Weekly Traffic</CardTitle>
                            <CardDescription>Desktop vs Mobile visitors this week</CardDescription>
                        </CardHeader>
                        <CardContent className="px-0 pb-0">
                            <ResponsiveContainer width="100%" height={350}>
                                <BarChart data={data}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
                                    <XAxis dataKey="name" stroke="#94a3b8" />
                                    <YAxis stroke="#94a3b8" />
                                    <Tooltip />
                                    <Legend />
                                    <Bar dataKey="desktop" fill="#635bff" radius={[4, 4, 0, 0]} />
                                    <Bar dataKey="mobile" fill="#00d4ff" radius={[4, 4, 0, 0]} />
                                </BarChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>
                );
            }
            """
        ),

        Template(
            id: "chart-pie",
            name: "Pie Chart",
            description: "Donut chart with category breakdown",
            category: .charts,
            code: """
            function PieChartDemo() {
                const data = [
                    { name: 'Chrome', value: 63.5, fill: '#635bff' },
                    { name: 'Safari', value: 19.8, fill: '#00d4ff' },
                    { name: 'Firefox', value: 8.4, fill: '#10b981' },
                    { name: 'Edge', value: 5.2, fill: '#f59e0b' },
                    { name: 'Other', value: 3.1, fill: '#94a3b8' },
                ];

                return (
                    <Card className="p-6">
                        <CardHeader className="px-0 pt-0">
                            <CardTitle>Browser Usage</CardTitle>
                            <CardDescription>Market share by browser this month</CardDescription>
                        </CardHeader>
                        <CardContent className="px-0 pb-0">
                            <ResponsiveContainer width="100%" height={300}>
                                <PieChart>
                                    <Pie
                                        data={data}
                                        cx="50%"
                                        cy="50%"
                                        innerRadius={60}
                                        outerRadius={100}
                                        paddingAngle={2}
                                        dataKey="value"
                                        label={({ name, value }) => `${name}: ${value}%`}
                                    >
                                        {data.map((entry, index) => (
                                            <Cell key={index} fill={entry.fill} />
                                        ))}
                                    </Pie>
                                    <Tooltip />
                                </PieChart>
                            </ResponsiveContainer>
                            <div className="flex flex-wrap justify-center gap-4 mt-4">
                                {data.map((item, i) => (
                                    <div key={i} className="flex items-center gap-2">
                                        <div className="w-3 h-3 rounded-full" style={{ backgroundColor: item.fill }} />
                                        <span className="text-sm text-slate-600">{item.name}</span>
                                    </div>
                                ))}
                            </div>
                        </CardContent>
                    </Card>
                );
            }
            """
        ),

        // MARK: - Form Templates

        Template(
            id: "form-login",
            name: "Login Form",
            description: "Clean authentication form with validation",
            category: .forms,
            code: """
            function LoginForm() {
                const [email, setEmail] = useState('');
                const [password, setPassword] = useState('');
                const [loading, setLoading] = useState(false);
                const [error, setError] = useState('');

                const handleSubmit = (e) => {
                    e.preventDefault();
                    setError('');
                    if (!email || !password) {
                        setError('Please fill in all fields');
                        return;
                    }
                    setLoading(true);
                    setTimeout(() => {
                        setLoading(false);
                        alert('Login successful!');
                    }, 1500);
                };

                return (
                    <div className="min-h-screen flex items-center justify-center bg-slate-50 dark:bg-slate-900 p-4">
                        <Card className="w-full max-w-md">
                            <CardHeader className="text-center">
                                <CardTitle className="text-2xl">Welcome back</CardTitle>
                                <CardDescription>Sign in to your account to continue</CardDescription>
                            </CardHeader>
                            <CardContent>
                                <form onSubmit={handleSubmit} className="space-y-4">
                                    {error && (
                                        <Alert variant="destructive">
                                            <AlertDescription>{error}</AlertDescription>
                                        </Alert>
                                    )}
                                    <div className="space-y-2">
                                        <Label htmlFor="email">Email</Label>
                                        <Input
                                            id="email"
                                            type="email"
                                            placeholder="name@example.com"
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <Label htmlFor="password">Password</Label>
                                        <Input
                                            id="password"
                                            type="password"
                                            placeholder="Enter your password"
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                        />
                                    </div>
                                    <Button className="w-full" disabled={loading}>
                                        {loading ? 'Signing in...' : 'Sign in'}
                                    </Button>
                                </form>
                            </CardContent>
                            <CardFooter className="flex flex-col gap-4">
                                <Separator />
                                <p className="text-sm text-slate-500 text-center">
                                    Don't have an account? <a href="#" className="text-primary font-medium">Sign up</a>
                                </p>
                            </CardFooter>
                        </Card>
                    </div>
                );
            }
            """
        ),

        Template(
            id: "form-contact",
            name: "Contact Form",
            description: "Multi-field contact form with textarea",
            category: .forms,
            code: """
            function ContactForm() {
                const [formData, setFormData] = useState({
                    name: '',
                    email: '',
                    subject: '',
                    message: ''
                });
                const [submitted, setSubmitted] = useState(false);

                const handleChange = (e) => {
                    setFormData({ ...formData, [e.target.name]: e.target.value });
                };

                const handleSubmit = (e) => {
                    e.preventDefault();
                    setSubmitted(true);
                };

                if (submitted) {
                    return (
                        <Card className="max-w-lg mx-auto p-8 text-center">
                            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                                <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                </svg>
                            </div>
                            <h3 className="text-xl font-semibold mb-2">Message Sent!</h3>
                            <p className="text-slate-500 mb-4">We'll get back to you within 24 hours.</p>
                            <Button variant="outline" onClick={() => setSubmitted(false)}>Send Another</Button>
                        </Card>
                    );
                }

                return (
                    <Card className="max-w-lg mx-auto">
                        <CardHeader>
                            <CardTitle>Get in Touch</CardTitle>
                            <CardDescription>Fill out the form below and we'll respond promptly.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <form onSubmit={handleSubmit} className="space-y-4">
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="space-y-2">
                                        <Label htmlFor="name">Name</Label>
                                        <Input id="name" name="name" placeholder="John Doe" value={formData.name} onChange={handleChange} required />
                                    </div>
                                    <div className="space-y-2">
                                        <Label htmlFor="email">Email</Label>
                                        <Input id="email" name="email" type="email" placeholder="john@example.com" value={formData.email} onChange={handleChange} required />
                                    </div>
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="subject">Subject</Label>
                                    <Input id="subject" name="subject" placeholder="How can we help?" value={formData.subject} onChange={handleChange} required />
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="message">Message</Label>
                                    <Textarea id="message" name="message" placeholder="Tell us more about your inquiry..." value={formData.message} onChange={handleChange} className="min-h-32" required />
                                </div>
                                <Button type="submit" className="w-full">Send Message</Button>
                            </form>
                        </CardContent>
                    </Card>
                );
            }
            """
        ),

        // MARK: - Card Templates

        Template(
            id: "card-profile",
            name: "Profile Card",
            description: "User profile card with avatar and stats",
            category: .cards,
            code: """
            function ProfileCard() {
                const user = {
                    name: 'Alex Thompson',
                    role: 'Senior Developer',
                    avatar: null,
                    stats: [
                        { label: 'Projects', value: '24' },
                        { label: 'Followers', value: '1.2k' },
                        { label: 'Following', value: '180' },
                    ],
                    skills: ['React', 'TypeScript', 'Node.js', 'GraphQL']
                };

                return (
                    <Card className="max-w-sm mx-auto overflow-hidden">
                        <div className="h-24 bg-gradient-to-r from-primary-500 to-purple-600" />
                        <CardContent className="-mt-12 text-center pb-6">
                            <Avatar className="w-24 h-24 mx-auto border-4 border-white dark:border-slate-900">
                                <AvatarFallback className="text-2xl bg-gradient-to-r from-primary-500 to-purple-600 text-white">
                                    {user.name.split(' ').map(n => n[0]).join('')}
                                </AvatarFallback>
                            </Avatar>
                            <h3 className="mt-4 text-xl font-semibold">{user.name}</h3>
                            <p className="text-slate-500">{user.role}</p>

                            <div className="flex justify-center gap-6 mt-6 py-4 border-y border-slate-100 dark:border-slate-800">
                                {user.stats.map((stat, i) => (
                                    <div key={i} className="text-center">
                                        <div className="text-xl font-bold">{stat.value}</div>
                                        <div className="text-xs text-slate-500">{stat.label}</div>
                                    </div>
                                ))}
                            </div>

                            <div className="flex flex-wrap justify-center gap-2 mt-4">
                                {user.skills.map((skill, i) => (
                                    <Badge key={i} variant="secondary">{skill}</Badge>
                                ))}
                            </div>

                            <div className="flex gap-2 mt-6">
                                <Button className="flex-1">Follow</Button>
                                <Button variant="outline" className="flex-1">Message</Button>
                            </div>
                        </CardContent>
                    </Card>
                );
            }
            """
        ),

        Template(
            id: "card-product",
            name: "Product Card",
            description: "E-commerce product card with image and actions",
            category: .cards,
            code: """
            function ProductCard() {
                const [isFavorite, setIsFavorite] = useState(false);

                const product = {
                    name: 'Premium Wireless Headphones',
                    description: 'High-fidelity audio with active noise cancellation',
                    price: 299.99,
                    originalPrice: 399.99,
                    rating: 4.8,
                    reviews: 128,
                    inStock: true
                };

                const discount = Math.round((1 - product.price / product.originalPrice) * 100);

                return (
                    <Card className="max-w-sm overflow-hidden group">
                        <div className="relative aspect-square bg-slate-100 dark:bg-slate-800">
                            <div className="absolute inset-0 flex items-center justify-center text-6xl">🎧</div>
                            <div className="absolute top-3 left-3">
                                <Badge variant="destructive">-{discount}%</Badge>
                            </div>
                            <button
                                onClick={() => setIsFavorite(!isFavorite)}
                                className="absolute top-3 right-3 w-9 h-9 rounded-full bg-white/90 dark:bg-slate-900/90 flex items-center justify-center shadow-sm hover:scale-110 transition-transform"
                            >
                                <svg className={`w-5 h-5 ${isFavorite ? 'text-red-500 fill-red-500' : 'text-slate-400'}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                                </svg>
                            </button>
                        </div>
                        <CardContent className="p-4">
                            <div className="flex items-center gap-1 mb-2">
                                <span className="text-yellow-400">★</span>
                                <span className="font-medium">{product.rating}</span>
                                <span className="text-slate-400">({product.reviews})</span>
                            </div>
                            <h3 className="font-semibold text-lg mb-1 line-clamp-1">{product.name}</h3>
                            <p className="text-sm text-slate-500 mb-3 line-clamp-2">{product.description}</p>
                            <div className="flex items-center gap-2 mb-4">
                                <span className="text-2xl font-bold">${product.price}</span>
                                <span className="text-slate-400 line-through">${product.originalPrice}</span>
                            </div>
                            <Button className="w-full">Add to Cart</Button>
                        </CardContent>
                    </Card>
                );
            }
            """
        ),

        // MARK: - Interactive Templates

        Template(
            id: "interactive-counter",
            name: "Animated Counter",
            description: "Interactive counter with smooth animations",
            category: .interactive,
            code: """
            function AnimatedCounter() {
                const [count, setCount] = useState(0);

                return (
                    <div className="flex flex-col items-center justify-center min-h-[300px] gap-8 p-8">
                        <div className="relative">
                            <div className="text-8xl font-bold bg-gradient-to-r from-primary-500 to-purple-600 bg-clip-text text-transparent">
                                {count}
                            </div>
                            <div className="absolute -inset-4 bg-gradient-to-r from-primary-500/20 to-purple-600/20 blur-2xl -z-10 rounded-full" />
                        </div>

                        <div className="flex gap-3">
                            <Button
                                variant="outline"
                                size="lg"
                                onClick={() => setCount(c => c - 1)}
                                className="w-16 h-16 rounded-full text-2xl"
                            >
                                -
                            </Button>
                            <Button
                                variant="secondary"
                                onClick={() => setCount(0)}
                                className="px-6"
                            >
                                Reset
                            </Button>
                            <Button
                                size="lg"
                                onClick={() => setCount(c => c + 1)}
                                className="w-16 h-16 rounded-full text-2xl"
                            >
                                +
                            </Button>
                        </div>

                        <p className="text-slate-500 text-sm">Click the buttons to change the counter</p>
                    </div>
                );
            }
            """
        ),

        Template(
            id: "interactive-toggle",
            name: "Theme Toggle",
            description: "Animated dark/light mode toggle switch",
            category: .interactive,
            code: """
            function ThemeToggle() {
                const [isDark, setIsDark] = useState(false);

                return (
                    <div className={`min-h-[400px] transition-colors duration-500 ${isDark ? 'bg-slate-900' : 'bg-white'} flex items-center justify-center`}>
                        <Card className={`p-8 text-center ${isDark ? 'bg-slate-800 border-slate-700' : ''}`}>
                            <div className="mb-6">
                                <span className="text-6xl">{isDark ? '🌙' : '☀️'}</span>
                            </div>

                            <h3 className={`text-xl font-semibold mb-2 ${isDark ? 'text-white' : ''}`}>
                                {isDark ? 'Dark Mode' : 'Light Mode'}
                            </h3>
                            <p className={`text-sm mb-6 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                Toggle to switch between themes
                            </p>

                            <div className="flex items-center justify-center gap-3">
                                <span className={isDark ? 'text-slate-500' : 'text-slate-900'}>☀️</span>
                                <Switch
                                    checked={isDark}
                                    onCheckedChange={setIsDark}
                                />
                                <span className={isDark ? 'text-white' : 'text-slate-500'}>🌙</span>
                            </div>
                        </Card>
                    </div>
                );
            }
            """
        ),

        Template(
            id: "interactive-tabs",
            name: "Feature Tabs",
            description: "Tabbed content with smooth transitions",
            category: .interactive,
            code: """
            function FeatureTabs() {
                const features = [
                    {
                        id: 'speed',
                        title: 'Lightning Fast',
                        icon: '⚡',
                        description: 'Built for speed with optimized performance across all devices and browsers.',
                        stats: [
                            { label: 'Load Time', value: '0.3s' },
                            { label: 'Lighthouse', value: '98' },
                        ]
                    },
                    {
                        id: 'secure',
                        title: 'Enterprise Security',
                        icon: '🔒',
                        description: 'Bank-grade encryption and security protocols to keep your data safe.',
                        stats: [
                            { label: 'Uptime', value: '99.99%' },
                            { label: 'Compliance', value: 'SOC2' },
                        ]
                    },
                    {
                        id: 'scale',
                        title: 'Infinite Scale',
                        icon: '📈',
                        description: 'From startup to enterprise, scale seamlessly without limits.',
                        stats: [
                            { label: 'Max Users', value: '∞' },
                            { label: 'Regions', value: '40+' },
                        ]
                    },
                ];

                return (
                    <Card className="max-w-2xl mx-auto">
                        <Tabs defaultValue="speed">
                            <TabsList className="w-full justify-start border-b rounded-none bg-transparent p-0">
                                {features.map(f => (
                                    <TabsTrigger
                                        key={f.id}
                                        value={f.id}
                                        className="data-[state=active]:border-b-2 data-[state=active]:border-primary-500 rounded-none"
                                    >
                                        <span className="mr-2">{f.icon}</span>
                                        {f.title}
                                    </TabsTrigger>
                                ))}
                            </TabsList>

                            {features.map(f => (
                                <TabsContent key={f.id} value={f.id} className="p-6">
                                    <div className="text-center mb-6">
                                        <span className="text-5xl">{f.icon}</span>
                                        <h3 className="text-2xl font-bold mt-4">{f.title}</h3>
                                        <p className="text-slate-500 mt-2 max-w-md mx-auto">{f.description}</p>
                                    </div>
                                    <div className="flex justify-center gap-8">
                                        {f.stats.map((s, i) => (
                                            <div key={i} className="text-center">
                                                <div className="text-3xl font-bold text-primary-600">{s.value}</div>
                                                <div className="text-sm text-slate-500">{s.label}</div>
                                            </div>
                                        ))}
                                    </div>
                                </TabsContent>
                            ))}
                        </Tabs>
                    </Card>
                );
            }
            """
        ),

        // MARK: - Marketing Templates

        Template(
            id: "marketing-hero",
            name: "Hero Section",
            description: "Landing page hero with gradient and CTA",
            category: .marketing,
            code: """
            function HeroSection() {
                return (
                    <div className="relative min-h-[600px] flex items-center justify-center overflow-hidden bg-slate-50 dark:bg-slate-900">
                        {/* Gradient background */}
                        <div className="absolute inset-0 bg-gradient-to-br from-primary-100 via-transparent to-purple-100 dark:from-primary-900/20 dark:to-purple-900/20" />
                        <div className="absolute top-0 right-0 w-1/2 h-1/2 bg-gradient-to-bl from-cyan-200/50 to-transparent dark:from-cyan-500/10 blur-3xl" />

                        <div className="relative z-10 max-w-4xl mx-auto text-center px-6">
                            <Badge className="mb-6" variant="secondary">
                                ✨ Introducing v2.0
                            </Badge>

                            <h1 className="text-5xl md:text-7xl font-bold tracking-tight mb-6 bg-gradient-to-r from-slate-900 via-primary-600 to-purple-600 dark:from-white dark:via-primary-400 dark:to-purple-400 bg-clip-text text-transparent">
                                Build beautiful apps faster
                            </h1>

                            <p className="text-xl text-slate-600 dark:text-slate-300 max-w-2xl mx-auto mb-8">
                                The modern development platform that helps teams ship 10x faster.
                                From prototype to production in record time.
                            </p>

                            <div className="flex flex-wrap justify-center gap-4">
                                <Button size="lg" className="px-8">
                                    Get Started Free
                                    <svg className="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                                    </svg>
                                </Button>
                                <Button size="lg" variant="outline">
                                    Watch Demo
                                </Button>
                            </div>

                            <div className="flex justify-center gap-8 mt-12 text-sm text-slate-500">
                                <div className="flex items-center gap-2">
                                    <svg className="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                    </svg>
                                    Free 14-day trial
                                </div>
                                <div className="flex items-center gap-2">
                                    <svg className="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                    </svg>
                                    No credit card required
                                </div>
                            </div>
                        </div>
                    </div>
                );
            }
            """
        ),

        Template(
            id: "marketing-pricing",
            name: "Pricing Table",
            description: "Three-tier pricing comparison cards",
            category: .marketing,
            code: """
            function PricingTable() {
                const plans = [
                    {
                        name: 'Starter',
                        price: 0,
                        description: 'Perfect for trying out our platform',
                        features: ['5 projects', '10GB storage', 'Basic analytics', 'Email support'],
                        cta: 'Start Free',
                        popular: false
                    },
                    {
                        name: 'Pro',
                        price: 29,
                        description: 'Best for growing businesses',
                        features: ['Unlimited projects', '100GB storage', 'Advanced analytics', 'Priority support', 'API access', 'Team collaboration'],
                        cta: 'Get Started',
                        popular: true
                    },
                    {
                        name: 'Enterprise',
                        price: 99,
                        description: 'For large-scale operations',
                        features: ['Everything in Pro', 'Unlimited storage', 'Custom integrations', 'Dedicated support', 'SLA guarantee', 'On-premise option'],
                        cta: 'Contact Sales',
                        popular: false
                    }
                ];

                return (
                    <div className="py-16 px-6 bg-slate-50 dark:bg-slate-900">
                        <div className="text-center mb-12">
                            <h2 className="text-4xl font-bold mb-4">Simple, transparent pricing</h2>
                            <p className="text-slate-500 max-w-xl mx-auto">Choose the plan that's right for you. All plans include a 14-day free trial.</p>
                        </div>

                        <div className="max-w-5xl mx-auto grid md:grid-cols-3 gap-6">
                            {plans.map((plan, i) => (
                                <Card key={i} className={`relative ${plan.popular ? 'border-primary-500 border-2 scale-105' : ''}`}>
                                    {plan.popular && (
                                        <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                                            <Badge>Most Popular</Badge>
                                        </div>
                                    )}
                                    <CardHeader className="text-center">
                                        <CardTitle>{plan.name}</CardTitle>
                                        <CardDescription>{plan.description}</CardDescription>
                                        <div className="mt-4">
                                            <span className="text-4xl font-bold">${plan.price}</span>
                                            <span className="text-slate-500">/month</span>
                                        </div>
                                    </CardHeader>
                                    <CardContent>
                                        <ul className="space-y-3">
                                            {plan.features.map((feature, j) => (
                                                <li key={j} className="flex items-center gap-2">
                                                    <svg className="w-5 h-5 text-green-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                                    </svg>
                                                    <span className="text-sm">{feature}</span>
                                                </li>
                                            ))}
                                        </ul>
                                    </CardContent>
                                    <CardFooter>
                                        <Button className="w-full" variant={plan.popular ? 'default' : 'outline'}>
                                            {plan.cta}
                                        </Button>
                                    </CardFooter>
                                </Card>
                            ))}
                        </div>
                    </div>
                );
            }
            """
        ),

        // MARK: - Analytics Templates

        Template(
            id: "analytics-kpi",
            name: "KPI Dashboard",
            description: "Key performance indicators with sparklines",
            category: .analytics,
            code: """
            function KPIDashboard() {
                const kpis = [
                    {
                        label: 'Revenue',
                        value: '$48,352',
                        change: 12.5,
                        data: [35, 42, 38, 45, 48, 52, 48],
                        color: '#635bff'
                    },
                    {
                        label: 'Users',
                        value: '24,521',
                        change: 8.2,
                        data: [20, 22, 21, 23, 24, 26, 25],
                        color: '#00d4ff'
                    },
                    {
                        label: 'Orders',
                        value: '1,847',
                        change: -3.1,
                        data: [20, 19, 18, 19, 17, 18, 18],
                        color: '#f59e0b'
                    },
                    {
                        label: 'Conversion',
                        value: '3.24%',
                        change: 5.7,
                        data: [2.8, 2.9, 3.0, 3.1, 3.2, 3.3, 3.2],
                        color: '#10b981'
                    },
                ];

                const Sparkline = ({ data, color }) => {
                    const max = Math.max(...data);
                    const min = Math.min(...data);
                    const range = max - min || 1;
                    const points = data.map((v, i) =>
                        `${(i / (data.length - 1)) * 100},${100 - ((v - min) / range) * 100}`
                    ).join(' ');

                    return (
                        <svg viewBox="0 0 100 100" className="w-24 h-12" preserveAspectRatio="none">
                            <polyline
                                points={points}
                                fill="none"
                                stroke={color}
                                strokeWidth="2"
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            />
                        </svg>
                    );
                };

                return (
                    <div className="p-6 bg-slate-50 dark:bg-slate-900 min-h-screen">
                        <h1 className="text-2xl font-bold mb-6">Analytics Overview</h1>
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                            {kpis.map((kpi, i) => (
                                <Card key={i} className="p-5">
                                    <div className="flex justify-between items-start">
                                        <div>
                                            <p className="text-sm text-slate-500">{kpi.label}</p>
                                            <p className="text-2xl font-bold mt-1">{kpi.value}</p>
                                            <div className={`flex items-center gap-1 mt-2 text-sm ${kpi.change >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                                        d={kpi.change >= 0 ? "M5 10l7-7m0 0l7 7m-7-7v18" : "M19 14l-7 7m0 0l-7-7m7 7V3"} />
                                                </svg>
                                                {Math.abs(kpi.change)}%
                                            </div>
                                        </div>
                                        <Sparkline data={kpi.data} color={kpi.color} />
                                    </div>
                                </Card>
                            ))}
                        </div>
                    </div>
                );
            }
            """
        ),

        Template(
            id: "analytics-table",
            name: "Data Table",
            description: "Sortable table with status badges",
            category: .analytics,
            code: """
            function DataTable() {
                const [sortField, setSortField] = useState('name');
                const [sortDir, setSortDir] = useState('asc');

                const data = [
                    { id: 1, name: 'Wireless Earbuds', category: 'Electronics', price: 129.99, stock: 45, status: 'In Stock' },
                    { id: 2, name: 'Laptop Stand', category: 'Accessories', price: 59.99, stock: 0, status: 'Out of Stock' },
                    { id: 3, name: 'USB-C Hub', category: 'Electronics', price: 79.99, stock: 12, status: 'Low Stock' },
                    { id: 4, name: 'Desk Lamp', category: 'Office', price: 45.00, stock: 78, status: 'In Stock' },
                    { id: 5, name: 'Keyboard', category: 'Electronics', price: 199.99, stock: 23, status: 'In Stock' },
                ];

                const sorted = [...data].sort((a, b) => {
                    const aVal = a[sortField];
                    const bVal = b[sortField];
                    const dir = sortDir === 'asc' ? 1 : -1;
                    if (typeof aVal === 'number') return (aVal - bVal) * dir;
                    return String(aVal).localeCompare(String(bVal)) * dir;
                });

                const toggleSort = (field) => {
                    if (sortField === field) {
                        setSortDir(d => d === 'asc' ? 'desc' : 'asc');
                    } else {
                        setSortField(field);
                        setSortDir('asc');
                    }
                };

                const statusStyles = {
                    'In Stock': 'success',
                    'Low Stock': 'warning',
                    'Out of Stock': 'destructive'
                };

                return (
                    <Card>
                        <CardHeader>
                            <CardTitle>Product Inventory</CardTitle>
                            <CardDescription>Manage your product stock levels</CardDescription>
                        </CardHeader>
                        <CardContent className="p-0">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        {['name', 'category', 'price', 'stock', 'status'].map(field => (
                                            <TableHead
                                                key={field}
                                                className="cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800"
                                                onClick={() => toggleSort(field)}
                                            >
                                                <div className="flex items-center gap-1">
                                                    {field.charAt(0).toUpperCase() + field.slice(1)}
                                                    {sortField === field && (
                                                        <span>{sortDir === 'asc' ? '↑' : '↓'}</span>
                                                    )}
                                                </div>
                                            </TableHead>
                                        ))}
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {sorted.map(row => (
                                        <TableRow key={row.id}>
                                            <TableCell className="font-medium">{row.name}</TableCell>
                                            <TableCell>{row.category}</TableCell>
                                            <TableCell>${row.price.toFixed(2)}</TableCell>
                                            <TableCell>{row.stock}</TableCell>
                                            <TableCell>
                                                <Badge variant={statusStyles[row.status]}>{row.status}</Badge>
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </CardContent>
                    </Card>
                );
            }
            """
        ),

        // MARK: - Commerce Templates

        Template(
            id: "commerce-cart",
            name: "Shopping Cart",
            description: "Cart with quantity controls and totals",
            category: .commerce,
            code: """
            function ShoppingCart() {
                const [items, setItems] = useState([
                    { id: 1, name: 'Premium Headphones', price: 299.99, quantity: 1, image: '🎧' },
                    { id: 2, name: 'Wireless Keyboard', price: 149.99, quantity: 2, image: '⌨️' },
                    { id: 3, name: 'USB-C Dock', price: 89.99, quantity: 1, image: '🔌' },
                ]);

                const updateQty = (id, delta) => {
                    setItems(items.map(item =>
                        item.id === id
                            ? { ...item, quantity: Math.max(0, item.quantity + delta) }
                            : item
                    ).filter(item => item.quantity > 0));
                };

                const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
                const shipping = subtotal > 100 ? 0 : 9.99;
                const tax = subtotal * 0.08;
                const total = subtotal + shipping + tax;

                return (
                    <div className="max-w-2xl mx-auto p-6">
                        <h1 className="text-2xl font-bold mb-6">Shopping Cart ({items.length})</h1>

                        {items.length === 0 ? (
                            <Card className="p-12 text-center">
                                <span className="text-6xl mb-4 block">🛒</span>
                                <h3 className="text-xl font-semibold mb-2">Your cart is empty</h3>
                                <p className="text-slate-500 mb-4">Add some items to get started</p>
                                <Button>Continue Shopping</Button>
                            </Card>
                        ) : (
                            <div className="grid gap-6">
                                <Card>
                                    <CardContent className="divide-y">
                                        {items.map(item => (
                                            <div key={item.id} className="py-4 flex items-center gap-4">
                                                <div className="w-16 h-16 bg-slate-100 dark:bg-slate-800 rounded-lg flex items-center justify-center text-3xl">
                                                    {item.image}
                                                </div>
                                                <div className="flex-1">
                                                    <h3 className="font-medium">{item.name}</h3>
                                                    <p className="text-slate-500">${item.price.toFixed(2)}</p>
                                                </div>
                                                <div className="flex items-center gap-2">
                                                    <Button variant="outline" size="icon" className="h-8 w-8" onClick={() => updateQty(item.id, -1)}>-</Button>
                                                    <span className="w-8 text-center">{item.quantity}</span>
                                                    <Button variant="outline" size="icon" className="h-8 w-8" onClick={() => updateQty(item.id, 1)}>+</Button>
                                                </div>
                                                <div className="w-24 text-right font-medium">
                                                    ${(item.price * item.quantity).toFixed(2)}
                                                </div>
                                            </div>
                                        ))}
                                    </CardContent>
                                </Card>

                                <Card>
                                    <CardContent className="py-4 space-y-3">
                                        <div className="flex justify-between text-slate-600">
                                            <span>Subtotal</span>
                                            <span>${subtotal.toFixed(2)}</span>
                                        </div>
                                        <div className="flex justify-between text-slate-600">
                                            <span>Shipping</span>
                                            <span>{shipping === 0 ? 'Free' : `$${shipping.toFixed(2)}`}</span>
                                        </div>
                                        <div className="flex justify-between text-slate-600">
                                            <span>Tax</span>
                                            <span>${tax.toFixed(2)}</span>
                                        </div>
                                        <Separator />
                                        <div className="flex justify-between text-lg font-bold">
                                            <span>Total</span>
                                            <span>${total.toFixed(2)}</span>
                                        </div>
                                        <Button className="w-full mt-4" size="lg">
                                            Proceed to Checkout
                                        </Button>
                                    </CardContent>
                                </Card>
                            </div>
                        )}
                    </div>
                );
            }
            """
        ),
    ]

    /// Get templates by category
    static func templates(for category: Category) -> [Template] {
        all.filter { $0.category == category }
    }

    /// Get a template by ID
    static func template(id: String) -> Template? {
        all.first { $0.id == id }
    }

    /// Search templates by name or description
    static func search(_ query: String) -> [Template] {
        let lowercased = query.lowercased()
        return all.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.description.lowercased().contains(lowercased)
        }
    }
}
