//
//  HomeViewController.swift
//  cool-ios
//
//  A deliberately conventional UIKit dashboard used as the native baseline.
//

import UIKit

final class HomeViewController: UIViewController {
    private enum ControlKey: String {
        case notifications
        case haptics
        case focusMode
    }

    private enum RowKind {
        case summary
        case quickActions
        case disclosure
        case value(String)
        case toggle(ControlKey)
        case segmented(ControlKey, items: [String])
    }

    private struct Row {
        let title: String
        let subtitle: String?
        let symbol: String?
        let tint: UIColor
        let kind: RowKind
    }

    private struct Section {
        let title: String?
        let footer: String?
        let rows: [Row]
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let profileHeaderView = ProfileHeaderView()

    private var toggleValues: [ControlKey: Bool] = [
        .notifications: true,
        .haptics: true,
    ]
    private var selectedSegments: [ControlKey: Int] = [
        .focusMode: 1,
    ]

    private var highestScoreRow: Row {
        let score = GameScoreManager.shared.highestScore
        return Row(
            title: "Highest Score: \(score)",
            subtitle: "Flappy Cat",
            symbol: "gamecontroller.fill",
            tint: .systemPurple,
            kind: .value("\(score)")
        )
    }

    private lazy var sections: [Section] = [
        Section(
            title: "YOUR WEEK",
            footer: nil,
            rows: [
                Row(title: "Weekly summary", subtitle: nil, symbol: nil, tint: .systemBlue, kind: .summary),
                Row(
                    title: "Activity snapshot",
                    subtitle: "You completed 12 tasks this week",
                    symbol: "chart.line.uptrend.xyaxis",
                    tint: .systemGreen,
                    kind: .disclosure
                ),
                highestScoreRow,
                Row(title: "Quick actions", subtitle: nil, symbol: nil, tint: .systemBlue, kind: .quickActions),
            ]
        ),
        Section(
            title: "PREFERENCES",
            footer: "Focus mode only changes how your dashboard is organized.",
            rows: [
                Row(
                    title: "Notifications",
                    subtitle: "Reminders and important updates",
                    symbol: "bell.fill",
                    tint: .systemRed,
                    kind: .toggle(.notifications)
                ),
                Row(
                    title: "Focus mode",
                    subtitle: "Choose what appears first",
                    symbol: "scope",
                    tint: .systemIndigo,
                    kind: .segmented(.focusMode, items: ["Off", "Work", "Life"])
                ),
                Row(
                    title: "Haptic feedback",
                    subtitle: "Use subtle feedback for actions",
                    symbol: "hand.tap.fill",
                    tint: .systemOrange,
                    kind: .toggle(.haptics)
                ),
            ]
        ),
        Section(
            title: "ACCOUNT",
            footer: nil,
            rows: [
                Row(title: "Personal information", subtitle: "Name, email, and profile photo", symbol: "person.crop.circle", tint: .systemBlue, kind: .disclosure),
                Row(title: "Privacy & security", subtitle: "Passcode, Face ID, and permissions", symbol: "lock.shield.fill", tint: .systemGreen, kind: .disclosure),
                Row(title: "Payment methods", subtitle: "Visa ending in 4242", symbol: "creditcard.fill", tint: .systemPurple, kind: .disclosure),
                Row(title: "Connected devices", subtitle: "2 active devices", symbol: "laptopcomputer.and.iphone", tint: .systemTeal, kind: .value("2")),
                Row(title: "Data & storage", subtitle: "Manage downloads and cache", symbol: "internaldrive.fill", tint: .systemGray, kind: .value("1.8 GB")),
            ]
        ),
        Section(
            title: "RECENT ACTIVITY",
            footer: "Activity is stored securely for 30 days.",
            rows: [
                Row(title: "Weekly plan completed", subtitle: "Today at 9:42 AM", symbol: "checkmark.circle.fill", tint: .systemGreen, kind: .disclosure),
                Row(title: "Subscription renewed", subtitle: "Yesterday", symbol: "arrow.triangle.2.circlepath", tint: .systemBlue, kind: .disclosure),
                Row(title: "Signed in on iPhone", subtitle: "Monday at 4:18 PM", symbol: "iphone", tint: .systemIndigo, kind: .disclosure),
                Row(title: "Cloud backup finished", subtitle: "Sunday at 11:06 PM", symbol: "icloud.fill", tint: .systemCyan, kind: .disclosure),
            ]
        ),
        Section(
            title: "SUPPORT",
            footer: "Hybrid Demo 1.0 (Build 42)",
            rows: [
                Row(title: "Help center", subtitle: "Guides and frequently asked questions", symbol: "questionmark.circle.fill", tint: .systemBlue, kind: .disclosure),
                Row(title: "What's new", subtitle: "See the latest improvements", symbol: "sparkles", tint: .systemPurple, kind: .disclosure),
                Row(title: "Send feedback", subtitle: "Tell us what could be better", symbol: "bubble.left.and.bubble.right.fill", tint: .systemOrange, kind: .disclosure),
                Row(title: "About", subtitle: "Licenses, policies, and acknowledgements", symbol: "info.circle.fill", tint: .systemGray, kind: .disclosure),
            ]
        ),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = .systemGroupedBackground

        configureTableView()
        configureProfileHeader()
        configureFooter()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onGameScoreUpdated),
            name: .gameScoreUpdated,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHighestScoreRow()
    }

    @objc private func onGameScoreUpdated() {
        updateHighestScoreRow()
    }

    private func updateHighestScoreRow() {
        guard !sections.isEmpty, sections[0].rows.count > 2 else { return }
        var updatedRows = sections[0].rows
        updatedRows[2] = highestScoreRow
        sections[0] = Section(title: sections[0].title, footer: sections[0].footer, rows: updatedRows)
        tableView.reloadRows(at: [IndexPath(row: 2, section: 0)], with: .none)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // UITableView does not use Auto Layout to size tableHeaderView itself.
        // Keeping its width in sync also makes rotation and split view predictable.
        let targetSize = CGSize(width: tableView.bounds.width, height: ProfileHeaderView.preferredHeight)
        if profileHeaderView.frame.size != targetSize {
            profileHeaderView.frame = CGRect(origin: .zero, size: targetSize)
            tableView.tableHeaderView = profileHeaderView
        }
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .systemGroupedBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.keyboardDismissMode = .onDrag
        tableView.register(WeeklySummaryCell.self, forCellReuseIdentifier: WeeklySummaryCell.reuseIdentifier)
        tableView.register(QuickActionsCell.self, forCellReuseIdentifier: QuickActionsCell.reuseIdentifier)
        tableView.register(SegmentedSettingCell.self, forCellReuseIdentifier: SegmentedSettingCell.reuseIdentifier)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureProfileHeader() {
        profileHeaderView.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: ProfileHeaderView.preferredHeight
        )
        profileHeaderView.editButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        tableView.tableHeaderView = profileHeaderView
    }

    private func configureFooter() {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 94))
        let signOutButton = UIButton(type: .system)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.setTitleColor(.systemRed, for: .normal)
        signOutButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        signOutButton.backgroundColor = .secondarySystemGroupedBackground
        signOutButton.layer.cornerRadius = 12
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        footer.addSubview(signOutButton)

        NSLayoutConstraint.activate([
            signOutButton.topAnchor.constraint(equalTo: footer.topAnchor, constant: 14),
            signOutButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 20),
            signOutButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -20),
            signOutButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        tableView.tableFooterView = footer
    }

    private func configureStandardCell(_ cell: UITableViewCell, with row: Row) {
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.secondaryText = row.subtitle
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 2

        if let symbol = row.symbol {
            content.image = UIImage(systemName: symbol)
            content.imageProperties.tintColor = row.tint
            content.imageProperties.maximumSize = CGSize(width: 28, height: 28)
        }

        cell.contentConfiguration = content
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.selectionStyle = .default

        switch row.kind {
        case .disclosure:
            cell.accessoryType = .disclosureIndicator
        case let .value(value):
            cell.accessoryView = makeValueLabel(value)
            cell.selectionStyle = .none
        case let .toggle(key):
            let toggle = UISwitch()
            toggle.isOn = toggleValues[key] ?? false
            toggle.accessibilityIdentifier = key.rawValue
            toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        case .summary, .quickActions, .segmented:
            break
        }
    }

    private func makeValueLabel(_ value: String) -> UILabel {
        let label = UILabel()
        label.text = value
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.sizeToFit()
        return label
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        guard let identifier = sender.accessibilityIdentifier,
              let key = ControlKey(rawValue: identifier) else { return }
        toggleValues[key] = sender.isOn
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        guard let identifier = sender.accessibilityIdentifier,
              let key = ControlKey(rawValue: identifier) else { return }
        selectedSegments[key] = sender.selectedSegmentIndex
    }

    @objc private func editProfileTapped() {
        provideSelectionFeedback(announcement: "Edit profile selected")
    }

    @objc private func signOutTapped() {
        provideSelectionFeedback(announcement: "Sign out selected")
    }

    private func provideSelectionFeedback(announcement: String) {
        UISelectionFeedbackGenerator().selectionChanged()
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        switch row.kind {
        case .summary:
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: WeeklySummaryCell.reuseIdentifier,
                for: indexPath
            ) as? WeeklySummaryCell else {
                return UITableViewCell()
            }
            return cell

        case .quickActions:
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: QuickActionsCell.reuseIdentifier,
                for: indexPath
            ) as? QuickActionsCell else {
                return UITableViewCell()
            }
            cell.onAction = { [weak self] title in
                self?.provideSelectionFeedback(announcement: "\(title) selected")
            }
            return cell

        case let .segmented(key, items):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: SegmentedSettingCell.reuseIdentifier,
                for: indexPath
            ) as? SegmentedSettingCell else {
                return UITableViewCell()
            }
            cell.configure(
                title: row.title,
                subtitle: row.subtitle,
                symbol: row.symbol,
                tint: row.tint,
                items: items,
                selectedIndex: selectedSegments[key] ?? 0,
                identifier: key.rawValue,
                target: self,
                action: #selector(segmentChanged(_:))
            )
            return cell

        case .disclosure, .value, .toggle:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DashboardRow")
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: "DashboardRow")
            configureStandardCell(cell, with: row)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section].rows[indexPath.row].kind {
        case .summary:
            return 110
        case .quickActions:
            return 94
        case .segmented:
            return 104
        case .disclosure, .value, .toggle:
            return 64
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        if case .disclosure = row.kind {
            provideSelectionFeedback(announcement: "\(row.title) selected")
        }
    }
}

private final class ProfileHeaderView: UIView {
    static let preferredHeight: CGFloat = 174

    let editButton = UIButton(type: .system)

    private let cardView = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusView = UIView()
    private let statusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 18
        addSubview(cardView)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.backgroundColor = .systemBlue
        avatarView.layer.cornerRadius = 34
        avatarView.accessibilityLabel = "Avery Davis profile photo"
        cardView.addSubview(avatarView)

        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.text = "AD"
        avatarLabel.font = .systemFont(ofSize: 23, weight: .bold)
        avatarLabel.textColor = .white
        avatarView.addSubview(avatarLabel)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = "Avery Davis"
        nameLabel.font = .preferredFont(forTextStyle: .title2)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = .label
        cardView.addSubview(nameLabel)

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.text = "Product designer · Bangkok"
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        cardView.addSubview(detailLabel)

        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.14)
        statusView.layer.cornerRadius = 10
        cardView.addSubview(statusView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "●  Available"
        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        statusLabel.textColor = .systemGreen
        statusView.addSubview(statusLabel)

        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        editButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        editButton.layer.cornerRadius = 15
        editButton.accessibilityHint = "Opens profile editing"
        cardView.addSubview(editButton)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            avatarView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 68),
            avatarView.heightAnchor.constraint(equalToConstant: 68),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 2),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),

            statusView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statusView.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 9),
            statusView.heightAnchor.constraint(equalToConstant: 20),

            statusLabel.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),

            editButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            editButton.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 54),
            editButton.heightAnchor.constraint(equalToConstant: 30),
        ])
    }
}

private final class WeeklySummaryCell: UITableViewCell {
    static let reuseIdentifier = "WeeklySummaryCell"

    private let metrics: [(String, String, String)] = [
        ("12", "Tasks", "checkmark.circle.fill"),
        ("5", "Day streak", "flame.fill"),
        ("8.4h", "Focused", "timer"),
    ]

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        configure()
    }

    private func configure() {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        contentView.addSubview(stack)

        var metricViews: [UIView] = []
        for (index, metric) in metrics.enumerated() {
            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(separator)
            }
            let metricView = makeMetric(value: metric.0, label: metric.1, symbol: metric.2)
            metricViews.append(metricView)
            stack.addArrangedSubview(metricView)
        }

        if let firstMetric = metricViews.first {
            for metricView in metricViews.dropFirst() {
                metricView.widthAnchor.constraint(equalTo: firstMetric.widthAnchor).isActive = true
            }
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
    }

    private func makeMetric(value: String, label: String, symbol: String) -> UIView {
        let container = UIView()

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        container.addSubview(icon)

        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 21, weight: .bold)
        valueLabel.textColor = .label
        container.addSubview(valueLabel)

        let descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = label
        descriptionLabel.font = .preferredFont(forTextStyle: .caption1)
        descriptionLabel.textColor = .secondaryLabel
        container.addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            valueLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 5),
            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            descriptionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])

        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(value) \(label)"
        return container
    }
}

private final class QuickActionsCell: UITableViewCell {
    static let reuseIdentifier = "QuickActionsCell"

    var onAction: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        configure()
    }

    private func configure() {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        contentView.addSubview(stack)

        [
            ("Add task", "plus.circle.fill"),
            ("Scan", "viewfinder"),
            ("Share", "square.and.arrow.up"),
        ].forEach { title, symbol in
            var configuration = UIButton.Configuration.tinted()
            configuration.title = title
            configuration.image = UIImage(systemName: symbol)
            configuration.imagePlacement = .top
            configuration.imagePadding = 6
            configuration.baseForegroundColor = .systemBlue
            configuration.cornerStyle = .medium

            let button = UIButton(configuration: configuration)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            button.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    @objc private func actionTapped(_ sender: UIButton) {
        guard let title = sender.configuration?.title else { return }
        onAction?(title)
    }
}

private final class SegmentedSettingCell: UITableViewCell {
    static let reuseIdentifier = "SegmentedSettingCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let segmentedControl = UISegmentedControl()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        configureViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        configureViews()
    }

    private func configureViews() {
        [iconView, titleLabel, subtitleLabel, segmentedControl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        iconView.contentMode = .scaleAspectFit
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),

            segmentedControl.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            segmentedControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            segmentedControl.heightAnchor.constraint(equalToConstant: 30),
            segmentedControl.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -9),
        ])
    }

    func configure(
        title: String,
        subtitle: String?,
        symbol: String?,
        tint: UIColor,
        items: [String],
        selectedIndex: Int,
        identifier: String,
        target: Any?,
        action: Selector
    ) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        iconView.image = symbol.flatMap(UIImage.init(systemName:))
        iconView.tintColor = tint

        segmentedControl.removeAllSegments()
        for (index, item) in items.enumerated() {
            segmentedControl.insertSegment(withTitle: item, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = min(selectedIndex, max(items.count - 1, 0))
        segmentedControl.accessibilityIdentifier = identifier
        segmentedControl.removeTarget(nil, action: nil, for: .valueChanged)
        segmentedControl.addTarget(target, action: action, for: .valueChanged)
    }
}
