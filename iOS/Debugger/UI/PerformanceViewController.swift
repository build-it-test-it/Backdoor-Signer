import UIKit

/// View controller for the performance tab in the debugger
class PerformanceViewController: UIViewController {
    // MARK: - Properties

    /// The debugger engine
    private let debuggerEngine = DebuggerEngine.shared

    /// Logger instance
    private let logger = Debug.shared

    /// Segmented control for switching between metrics
    private let segmentedControl: UISegmentedControl = {
        let items = ["CPU", "Memory", "GPU", "Energy"]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 0
        return segmentedControl
    }()

    /// Chart view
    private let chartView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemBackground
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray4.cgColor
        view.layer.cornerRadius = 8
        return view
    }()

    /// Current usage label
    private let currentUsageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    /// Usage description label
    private let usageDescriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        return label
    }()

    /// Stats table view
    private let statsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "StatCell")
        return tableView
    }()

    /// Current metric type
    private var currentMetricType: MetricType = .cpu

    /// Timer for updating metrics
    private var updateTimer: Timer?

    /// Performance metrics
    private var metrics: PerformanceMetricsData = .init()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupActions()

        // Set title
        title = "Performance"

        // Start monitoring
        startMonitoring()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Resume monitoring if needed
        if updateTimer == nil {
            startMonitoring()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause monitoring
        stopMonitoring()
    }

    // MARK: - Setup

    private func setupUI() {
        // Set background color
        view.backgroundColor = UIColor.systemBackground

        // Add segmented control
        view.addSubview(segmentedControl)

        // Add chart view
        view.addSubview(chartView)

        // Add current usage label
        chartView.addSubview(currentUsageLabel)

        // Add usage description label
        chartView.addSubview(usageDescriptionLabel)

        // Add stats table view
        view.addSubview(statsTableView)

        // Set up constraints
        NSLayoutConstraint.activate([
            // Segmented control
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 16
            ),
            segmentedControl.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),

            // Chart view
            chartView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            chartView.heightAnchor.constraint(equalToConstant: 200),

            // Current usage label
            currentUsageLabel.centerXAnchor.constraint(equalTo: chartView.centerXAnchor),
            currentUsageLabel.centerYAnchor.constraint(equalTo: chartView.centerYAnchor, constant: -16),

            // Usage description label
            usageDescriptionLabel.centerXAnchor.constraint(equalTo: chartView.centerXAnchor),
            usageDescriptionLabel.topAnchor.constraint(equalTo: currentUsageLabel.bottomAnchor, constant: 8),

            // Stats table view
            statsTableView.topAnchor.constraint(equalTo: chartView.bottomAnchor, constant: 16),
            statsTableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            statsTableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            statsTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        // Set up table view
        statsTableView.delegate = self
        statsTableView.dataSource = self
    }

    private func setupActions() {
        // Add target for segmented control
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }

    // MARK: - Actions

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        // Update current metric type
        switch sender.selectedSegmentIndex {
        case 0:
            currentMetricType = .cpu
        case 1:
            currentMetricType = .memory
        case 2:
            currentMetricType = .gpu
        case 3:
            currentMetricType = .energy
        default:
            currentMetricType = .cpu
        }

        // Update UI
        updateUI()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Start update timer
        updateTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(updateMetrics),
            userInfo: nil,
            repeats: true
        )

        // Update metrics immediately
        updateMetrics()
    }

    private func stopMonitoring() {
        // Stop update timer
        updateTimer?.invalidate()
        updateTimer = nil
    }

    @objc private func updateMetrics() {
        // In a real implementation, this would use real performance monitoring APIs
        // For now, just generate random metrics

        // Update CPU usage
        metrics.cpuUsage = min(max(metrics.cpuUsage + Double.random(in: -10 ... 10), 0), 100)

        // Update memory usage
        metrics.memoryUsage = min(max(metrics.memoryUsage + Double.random(in: -20 ... 20), 0), 1024)

        // Update GPU usage
        metrics.gpuUsage = min(max(metrics.gpuUsage + Double.random(in: -5 ... 5), 0), 100)

        // Update energy impact
        metrics.energyImpact = min(max(metrics.energyImpact + Double.random(in: -0.2 ... 0.2), 0), 10)

        // Update UI
        updateUI()
    }

    private func updateUI() {
        // Update current usage label and description based on metric type
        switch currentMetricType {
        case .cpu:
            currentUsageLabel.text = String(format: "%.1f%%", metrics.cpuUsage)
            usageDescriptionLabel.text = "CPU Usage"
            currentUsageLabel.textColor = getColorForPercentage(metrics.cpuUsage)
        case .memory:
            currentUsageLabel.text = String(format: "%.1f MB", metrics.memoryUsage)
            usageDescriptionLabel.text = "Memory Usage"
            currentUsageLabel.textColor = getColorForPercentage(metrics.memoryUsage / 10)
        case .gpu:
            currentUsageLabel.text = String(format: "%.1f%%", metrics.gpuUsage)
            usageDescriptionLabel.text = "GPU Usage"
            currentUsageLabel.textColor = getColorForPercentage(metrics.gpuUsage)
        case .energy:
            currentUsageLabel.text = String(format: "%.1f", metrics.energyImpact)
            usageDescriptionLabel.text = "Energy Impact"
            currentUsageLabel.textColor = getColorForPercentage(metrics.energyImpact * 10)
        }

        // Reload stats table
        statsTableView.reloadData()
    }

    private func getColorForPercentage(_ percentage: Double) -> UIColor {
        if percentage < 30 {
            return UIColor.systemGreen
        } else if percentage < 70 {
            return UIColor.systemOrange
        } else {
            return UIColor.systemRed
        }
    }
}

// MARK: - UITableViewDelegate

extension PerformanceViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension PerformanceViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        switch currentMetricType {
        case .cpu:
            return cpuStats.count
        case .memory:
            return memoryStats.count
        case .gpu:
            return gpuStats.count
        case .energy:
            return energyStats.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatCell", for: indexPath)

        // Configure cell based on metric type
        switch currentMetricType {
        case .cpu:
            let stat = cpuStats[indexPath.row]
            cell.textLabel?.text = stat.name
            cell.detailTextLabel?.text = stat.value
        case .memory:
            let stat = memoryStats[indexPath.row]
            cell.textLabel?.text = stat.name
            cell.detailTextLabel?.text = stat.value
        case .gpu:
            let stat = gpuStats[indexPath.row]
            cell.textLabel?.text = stat.name
            cell.detailTextLabel?.text = stat.value
        case .energy:
            let stat = energyStats[indexPath.row]
            cell.textLabel?.text = stat.name
            cell.detailTextLabel?.text = stat.value
        }

        return cell
    }

    // MARK: - Stats

    private var cpuStats: [(name: String, value: String)] {
        return [
            ("System CPU Usage", String(format: "%.1f%%", metrics.cpuUsage)),
            ("User CPU Usage", String(format: "%.1f%%", metrics.cpuUsage * 0.7)),
            ("Idle CPU", String(format: "%.1f%%", 100 - metrics.cpuUsage)),
            ("Number of Threads", "12"),
            ("Number of Processes", "1"),
        ]
    }

    private var memoryStats: [(name: String, value: String)] {
        return [
            ("Physical Memory Used", String(format: "%.1f MB", metrics.memoryUsage)),
            ("Virtual Memory Used", String(format: "%.1f MB", metrics.memoryUsage * 1.5)),
            ("Memory Pressure", metrics.memoryUsage > 500 ? "High" : "Normal"),
            ("Dirty Memory", String(format: "%.1f MB", metrics.memoryUsage * 0.2)),
            ("Compressed Memory", String(format: "%.1f MB", metrics.memoryUsage * 0.1)),
        ]
    }

    private var gpuStats: [(name: String, value: String)] {
        return [
            ("GPU Usage", String(format: "%.1f%%", metrics.gpuUsage)),
            ("Tiler Utilization", String(format: "%.1f%%", metrics.gpuUsage * 0.8)),
            ("Renderer Utilization", String(format: "%.1f%%", metrics.gpuUsage * 0.9)),
            ("Frame Rate", String(format: "%.1f fps", 60 - (metrics.gpuUsage / 5))),
            ("VRAM Usage", String(format: "%.1f MB", metrics.gpuUsage * 5)),
        ]
    }

    private var energyStats: [(name: String, value: String)] {
        return [
            ("Energy Impact", String(format: "%.1f", metrics.energyImpact)),
            ("Battery Drain", String(format: "%.1f%%/hr", metrics.energyImpact * 5)),
            ("CPU Energy", String(format: "%.1f", metrics.energyImpact * 0.6)),
            ("GPU Energy", String(format: "%.1f", metrics.energyImpact * 0.3)),
            ("Network Energy", String(format: "%.1f", metrics.energyImpact * 0.1)),
        ]
    }
}

// MARK: - Supporting Types

/// Metric type
enum MetricType {
    case cpu
    case memory
    case gpu
    case energy
}

/// Performance metrics
struct PerformanceMetricsData {
    var cpuUsage: Double = 25.0
    var memoryUsage: Double = 256.0
    var gpuUsage: Double = 15.0
    var energyImpact: Double = 3.0
}
