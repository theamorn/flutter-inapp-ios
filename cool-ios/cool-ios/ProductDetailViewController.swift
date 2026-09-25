//
//  ProductDetailViewController.swift
//  cool-ios
//
//  Tab 4: a conventional UIKit product page with one Flutter tile inside it.
//

import UIKit

/// A native product page, with the `/promo` Flutter tile halfway down.
///
/// UIKit owns everything around the tile: layout, scrolling, the price, and
/// the success haptic. The page tells Flutter where the tile sits (`scroll`),
/// whether it can be seen (`visibility`), and which drags are Flutter's
/// (`ProductScrollView`). Flutter draws the badge and, when it is tapped,
/// hands back the promo code; the page fills its own native promo field with
/// it, validates it, and reprices.
final class ProductDetailViewController: UIViewController, FlutterRouteHosting {
    let route = AppEngines.promoRoute

    /// A tile this close to the viewport counts as visible, so its engine is
    /// already drawing by the time it scrolls into view.
    private static let visibilityMargin: CGFloat = 120
    private static let basePrice = 249.0
    private static let discount = 0.2
    private static let promoCode = "HOLO20"

    private let scrollView = ProductScrollView()
    private let stack = UIStackView()
    private let promoTile = InlineFlutterCardViewController()
    private let priceLabel = UILabel()
    private let promoField = UITextField()
    private let promoApplyButton = UIButton(configuration: .tinted())
    private var discounted = false
    private var lastScroll: (offset: CGFloat, time: CFTimeInterval)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shop"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground

        configureScrollView()
        buildPage()

        // Flutter only reports the code. Everything after that is native: the
        // field fills in, and the page validates the code and reprices.
        promoTile.onClaim = { [weak self] code in self?.receivePromoCode(fromFlutter: code) }
        promoTile.hostState = { [weak self] in
            self?.promoState() ?? (visible: true, progress: 0)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Layout is final now; correct anything Flutter pulled too early.
        promoTile.sendVisibility(promoState().visible, force: true)
    }

    // MARK: - Layout

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.flutterTile = promoTile
        // Pinned to the safe area, so content never slides under the bars:
        // the Flutter tile's safe-area insets stay zero while scrolling, and
        // its viewport metrics never change mid-scroll.
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 22
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 32, trailing: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func buildPage() {
        stack.addArrangedSubview(makeHero())
        stack.addArrangedSubview(section("OPTIONS", rows: [
            makeSegmentedRow(title: "Color", items: ["Midnight", "Silver", "Sky"]),
            makeRow(symbol: "shippingbox.fill", tint: .systemBrown, title: "In the box", value: "Case, USB-C cable"),
        ]))
        stack.addArrangedSubview(section("HIGHLIGHTS", rows: [
            makeRow(symbol: "waveform", tint: .systemPurple, title: "Adaptive noise cancelling", detail: "Tunes itself to your ears 200 times a second"),
            makeRow(symbol: "battery.100percent.bolt", tint: .systemGreen, title: "38-hour battery", detail: "10 minutes of charging gives 5 hours"),
            makeRow(symbol: "airpods.gen3", tint: .systemBlue, title: "Spatial audio", detail: "Head tracking for movies and games"),
            makeRow(symbol: "mic.fill", tint: .systemOrange, title: "Six-mic calls", detail: "Beamforming that ignores wind"),
            makeRow(symbol: "leaf.fill", tint: .systemMint, title: "Recycled aluminium", detail: "Frame made from 100% recycled metal"),
        ]))

        addChild(promoTile)
        stack.addArrangedSubview(promoTile.view)
        promoTile.view.heightAnchor.constraint(equalToConstant: InlineFlutterCardViewController.height).isActive = true
        promoTile.didMove(toParent: self)

        stack.addArrangedSubview(section("SPECIFICATIONS", rows: [
            makeRow(title: "Driver", value: "40 mm dynamic"),
            makePromoCodeRow(),
        ] + [
            ("Frequency response", "4 Hz – 40 kHz"),
            ("Noise cancelling", "Hybrid adaptive"), ("Battery", "38 h (ANC on)"),
            ("Charging", "USB-C, wireless"), ("Bluetooth", "5.4, LE Audio"),
            ("Codecs", "AAC · LC3 · SBC"), ("Weight", "254 g"),
            ("Microphones", "6, beamforming"), ("Water resistance", "IPX4"),
        ].map { makeRow(title: $0.0, value: $0.1) }))
        stack.addArrangedSubview(section("REVIEWS", rows: [
            ("Maya R.", 5, "The noise cancelling on a train is unreal."),
            ("Tomás", 5, "Comfortable for a full workday."),
            ("Priya K.", 4, "Great sound, the case is a little bulky."),
            ("Jun", 5, "Battery lasted a whole week of commuting."),
            ("Alex", 4, "Calls are clear, even outdoors."),
            ("Sam W.", 5, "Spatial audio makes movies feel huge."),
        ].map { makeReviewRow(name: $0.0, stars: $0.1, text: $0.2) }))
        stack.addArrangedSubview(section("SHIPPING & RETURNS", rows: [
            makeRow(symbol: "truck.box.fill", tint: .systemBlue, title: "Free delivery", detail: "Arrives by Friday"),
            makeRow(symbol: "arrow.uturn.backward.circle.fill", tint: .systemGreen, title: "Free returns", detail: "Within 30 days"),
            makeRow(symbol: "checkmark.shield.fill", tint: .systemIndigo, title: "2-year warranty", detail: "Repairs and replacements"),
            makeRow(symbol: "storefront.fill", tint: .systemOrange, title: "Pick up in store", detail: "Ready in 2 hours"),
        ]))
        stack.addArrangedSubview(section("QUESTIONS", rows: [
            "Can I use them with two devices at once?",
            "Do they fold flat for travel?",
            "Is there a wired mode?",
            "How do I update the firmware?",
            "Can I replace the ear cushions?",
        ].map { makeRow(symbol: "questionmark.circle.fill", tint: .systemGray, title: $0, disclosure: true) }))

        let footer = UILabel()
        footer.text = "Nimbus One is a demo product. Prices in USD."
        footer.font = .preferredFont(forTextStyle: .footnote)
        footer.textColor = .secondaryLabel
        footer.textAlignment = .center
        stack.addArrangedSubview(footer)
    }

    // MARK: - Talking to the tile

    /// Where the tile is relative to the viewport, per the promo contract.
    private func promoState() -> (visible: Bool, progress: Double) {
        let tile = promoTile.view.convert(promoTile.view.bounds, to: scrollView)
        let viewport = scrollView.bounds
        let visible = viewport.insetBy(dx: 0, dy: -Self.visibilityMargin).intersects(tile)
        let progress = (tile.midY - viewport.midY) / max(viewport.height / 2, 1)
        return (visible, Double(min(max(progress, -1.5), 1.5)))
    }

    private func reportScroll() {
        let now = CACurrentMediaTime()
        let offset = scrollView.contentOffset.y
        var velocity = 0.0
        if let last = lastScroll, now > last.time {
            velocity = Double((offset - last.offset) / CGFloat(now - last.time))
        }
        lastScroll = (offset, now)

        let state = promoState()
        promoTile.sendVisibility(state.visible)
        if state.visible {
            promoTile.sendScroll(progress: state.progress, velocity: velocity)
        }
    }

    // MARK: - Promo code, processed natively

    /// The Flutter badge's callback lands here: show the code in the native
    /// field, so the audience can see the data arrive, then process it.
    private func receivePromoCode(fromFlutter code: String) {
        promoField.text = code
        UIView.animate(withDuration: 0.2, animations: {
            self.promoField.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.25)
        }, completion: { _ in
            UIView.animate(withDuration: 0.6) { self.promoField.backgroundColor = .tertiarySystemFill }
        })
        applyPromoCode()
    }

    @objc private func applyPromoCode() {
        let code = (promoField.text ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        guard code == Self.promoCode else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [-10, 10, -7, 7, -3, 3, 0]
            shake.duration = 0.4
            promoField.layer.add(shake, forKey: "shake")
            return
        }
        promoField.resignFirstResponder()
        promoField.isEnabled = false
        promoField.textColor = .systemPurple
        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        check.tintColor = .systemPurple
        check.contentMode = .center
        check.frame = CGRect(x: 0, y: 0, width: 36, height: 24)
        promoField.rightView = check
        promoField.rightViewMode = .always
        promoApplyButton.configuration?.title = "Applied"
        promoApplyButton.configuration?.image = UIImage(systemName: "checkmark")
        promoApplyButton.isEnabled = false
        applyDiscount()
    }

    private func applyDiscount() {
        guard !discounted else { return }
        discounted = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIView.transition(with: priceLabel, duration: 0.35, options: .transitionCrossDissolve) {
            self.priceLabel.attributedText = self.priceText()
        }
        UIView.animate(withDuration: 0.18, animations: {
            self.priceLabel.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
        }, completion: { _ in
            UIView.animate(withDuration: 0.25) { self.priceLabel.transform = .identity }
        })
    }

    private func priceText() -> NSAttributedString {
        let price = UIFont.systemFont(ofSize: 28, weight: .bold)
        guard discounted else {
            return NSAttributedString(
                string: String(format: "$%.2f", Self.basePrice),
                attributes: [.font: price, .foregroundColor: UIColor.label]
            )
        }
        let text = NSMutableAttributedString(
            string: String(format: "$%.2f", Self.basePrice * (1 - Self.discount)),
            attributes: [.font: price, .foregroundColor: UIColor.systemPurple]
        )
        text.append(NSAttributedString(
            string: String(format: "  $%.2f", Self.basePrice),
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            ]
        ))
        text.append(NSAttributedString(
            string: "  −20% HOLO20",
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.systemPurple,
            ]
        ))
        return text
    }

    // MARK: - Building blocks

    private func makeHero() -> UIView {
        let artwork = UIImageView(image: UIImage(systemName: "headphones"))
        artwork.tintColor = .white
        artwork.contentMode = .scaleAspectFit
        artwork.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 96, weight: .light)

        let artworkBackground = GradientView(colors: [.systemIndigo, .systemPurple])
        artworkBackground.layer.cornerRadius = 20
        artworkBackground.layer.cornerCurve = .continuous
        artworkBackground.clipsToBounds = true
        artwork.translatesAutoresizingMaskIntoConstraints = false
        artworkBackground.addSubview(artwork)
        NSLayoutConstraint.activate([
            artworkBackground.heightAnchor.constraint(equalToConstant: 220),
            artwork.centerXAnchor.constraint(equalTo: artworkBackground.centerXAnchor),
            artwork.centerYAnchor.constraint(equalTo: artworkBackground.centerYAnchor),
        ])

        let name = UILabel()
        name.text = "Nimbus One"
        name.font = .systemFont(ofSize: 30, weight: .bold)
        let summary = UILabel()
        summary.text = "Wireless noise-cancelling headphones"
        summary.font = .preferredFont(forTextStyle: .subheadline)
        summary.textColor = .secondaryLabel
        let rating = UILabel()
        rating.text = "★★★★★  4.7 · 2,184 reviews"
        rating.font = .preferredFont(forTextStyle: .footnote)
        rating.textColor = .systemOrange
        priceLabel.attributedText = priceText()

        let details = UIStackView(arrangedSubviews: [name, summary, rating, priceLabel])
        details.axis = .vertical
        details.spacing = 6
        details.setCustomSpacing(12, after: rating)

        let hero = UIStackView(arrangedSubviews: [artworkBackground, details])
        hero.axis = .vertical
        hero.spacing = 16
        return hero
    }

    private func section(_ title: String, rows: [UIView]) -> UIView {
        let header = UILabel()
        header.text = title
        header.font = .preferredFont(forTextStyle: .footnote)
        header.textColor = .secondaryLabel

        let card = UIStackView()
        card.axis = .vertical
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = .separator
                separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
                let inset = UIStackView(arrangedSubviews: [separator])
                inset.isLayoutMarginsRelativeArrangement = true
                inset.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0)
                card.addArrangedSubview(inset)
            }
            card.addArrangedSubview(row)
        }

        let section = UIStackView(arrangedSubviews: [header, card])
        section.axis = .vertical
        section.spacing = 8
        return section
    }

    private func makeRow(
        symbol: String? = nil,
        tint: UIColor = .systemBlue,
        title: String,
        detail: String? = nil,
        value: String? = nil,
        disclosure: Bool = false
    ) -> UIView {
        var views: [UIView] = []
        if let symbol {
            let icon = UIImageView(image: UIImage(systemName: symbol))
            icon.tintColor = tint
            icon.contentMode = .scaleAspectFit
            icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
            views.append(icon)
        }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.numberOfLines = 0
        let text = UIStackView(arrangedSubviews: [titleLabel])
        text.axis = .vertical
        text.spacing = 2
        if let detail {
            let detailLabel = UILabel()
            detailLabel.text = detail
            detailLabel.font = .preferredFont(forTextStyle: .footnote)
            detailLabel.textColor = .secondaryLabel
            detailLabel.numberOfLines = 0
            text.addArrangedSubview(detailLabel)
        }
        views.append(text)

        if let value {
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = .preferredFont(forTextStyle: .body)
            valueLabel.textColor = .secondaryLabel
            valueLabel.textAlignment = .right
            valueLabel.setContentHuggingPriority(.required, for: .horizontal)
            views.append(valueLabel)
        }
        if disclosure {
            let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
            chevron.tintColor = .tertiaryLabel
            chevron.setContentHuggingPriority(.required, for: .horizontal)
            views.append(chevron)
        }
        return rowContainer(views)
    }

    private func makePromoCodeRow() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "tag.fill"))
        icon.tintColor = .systemPurple
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true

        promoField.placeholder = "Promo code"
        promoField.accessibilityIdentifier = "promoCodeField"
        promoField.font = .monospacedSystemFont(ofSize: 17, weight: .semibold)
        promoField.autocapitalizationType = .allCharacters
        promoField.autocorrectionType = .no
        promoField.returnKeyType = .done
        promoField.backgroundColor = .tertiarySystemFill
        promoField.layer.cornerRadius = 10
        promoField.layer.cornerCurve = .continuous
        promoField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        promoField.leftViewMode = .always
        promoField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        promoField.addTarget(self, action: #selector(applyPromoCode), for: .editingDidEndOnExit)

        promoApplyButton.configuration?.title = "Apply"
        promoApplyButton.configuration?.imagePadding = 4
        promoApplyButton.tintColor = .systemPurple
        promoApplyButton.setContentHuggingPriority(.required, for: .horizontal)
        promoApplyButton.addTarget(self, action: #selector(applyPromoCode), for: .touchUpInside)

        return rowContainer([icon, promoField, promoApplyButton])
    }

    private func makeSegmentedRow(title: String, items: [String]) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.setContentHuggingPriority(.required, for: .horizontal)
        return rowContainer([label, control])
    }

    private func makeReviewRow(name: String, stars: Int, text: String) -> UIView {
        let header = UILabel()
        header.text = "\(String(repeating: "★", count: stars))\(String(repeating: "☆", count: 5 - stars))  \(name)"
        header.font = .preferredFont(forTextStyle: .subheadline)
        header.textColor = .systemOrange
        let body = UILabel()
        body.text = text
        body.font = .preferredFont(forTextStyle: .body)
        body.numberOfLines = 0
        let column = UIStackView(arrangedSubviews: [header, body])
        column.axis = .vertical
        column.spacing = 4
        return rowContainer([column])
    }

    private func rowContainer(_ views: [UIView]) -> UIView {
        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        return row
    }
}

extension ProductDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        reportScroll()
    }
}

/// Decides, per touch, whether a drag scrolls the page or belongs to Flutter.
///
/// A drag that starts on the badge is Flutter's: the page must not steal it
/// once it moves. Any other drag, including one on the tile's empty area,
/// scrolls the page as usual.
final class ProductScrollView: UIScrollView {
    weak var flutterTile: InlineFlutterCardViewController?
    private var touchStart: CGPoint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Deliver touches to the tile at once, so grabbing the badge feels
        // immediate and touchesShouldCancel(in:) decides every drag.
        delaysContentTouches = false
        canCancelContentTouches = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
        if let tile = flutterTile?.view, view.isDescendant(of: tile), let touch = touches.first {
            touchStart = touch.location(in: tile)
        } else {
            touchStart = nil
        }
        return super.touchesShouldBegin(touches, with: event, in: view)
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        if let tile = flutterTile, view.isDescendant(of: tile.view),
           let start = touchStart, tile.ownsTouch(startingAt: start) {
            return false
        }
        return super.touchesShouldCancel(in: view)
    }
}

/// A view whose layer is a vertical gradient, sized with the view.
private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    init(colors: [UIColor]) {
        super.init(frame: .zero)
        let gradient = layer as! CAGradientLayer
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
