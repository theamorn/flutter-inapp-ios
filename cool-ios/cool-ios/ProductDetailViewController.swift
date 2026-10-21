//
//  ProductDetailViewController.swift
//  cool-ios
//
//  Tab 4: a conventional UIKit product page with one Flutter tile inside it.
//

import UIKit

/// A native product page with three Flutter views in it, one engine each:
///
/// - `/product`, the 3D headphones at the top, which the user can orbit.
/// - `/promo`, the holo badge tile halfway down the Overview tab.
/// - `/reviews`, the whole Review Details tab, drawn with Liquid Glass.
///
/// UIKit owns everything around them: layout, scrolling, the Overview |
/// Review Details switch, the price, and the success haptic. The page tells
/// each view whether it can be seen (`visibility`) and decides which drags
/// are Flutter's (`ProductScrollView`). Flutter draws the badge and, when it
/// is tapped, hands back the promo code; the page fills its own native promo
/// field with it, validates it, and reprices.
final class ProductDetailViewController: UIViewController, FlutterRouteHosting {
    /// The HUD reports the Flutter view that owns the screen: the 3D header
    /// on Overview, the glass panel on Review Details.
    var route: String {
        segment.selectedSegmentIndex == 1 ? AppEngines.reviewsRoute : AppEngines.productRoute
    }

    /// A tile this close to the viewport counts as visible, so its engine is
    /// already drawing by the time it scrolls into view.
    private static let visibilityMargin: CGFloat = 120
    private static let basePrice = 249.0
    private static let discount = 0.2
    private static let promoCode = "HOLO20"
    private static let headerHeight: CGFloat = 280
    /// Space above the segmented control once Review Details pins it.
    private static let pinnedGap: CGFloat = 8
    private static let segmentSpacing: CGFloat = 16
    private static let stackBottomMargin: CGFloat = 32
    /// The Flutter tab's background, so there is no seam and no flash.
    private static let reviewsBackdrop = UIColor(red: 242 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1)

    private let scrollView = ProductScrollView()
    private let stack = UIStackView()
    private let promoTile = InlineFlutterCardViewController()
    private let productHeader = EmbeddedFlutterViewController(
        route: AppEngines.productRoute,
        channelName: AppEngines.productChannelName,
        backdropColor: .systemIndigo,
        cornerRadius: 20
    )
    private let reviewsPanel = EmbeddedFlutterViewController(
        route: AppEngines.reviewsRoute,
        channelName: AppEngines.reviewsChannelName,
        backdropColor: reviewsBackdrop,
        cornerRadius: 20
    )
    private let segment = UISegmentedControl(items: ["Overview", "Review Details"])
    private let overviewStack = UIStackView()
    private var reviewsHeight: NSLayoutConstraint?
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

    override func viewWillAppear(_ animated: Bool) {
        // All three engines spawn on the tab's first appearance: never on the
        // segment tap, where a synchronous engine start would hitch it. They
        // spawn as one measured step, before the promo tile's own appearance
        // callback can start its engine alone.
        AppEngines.shared.spawnShopEngines()
        super.viewWillAppear(animated)
        productHeader.embedIfNeeded()
        reviewsPanel.embedIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Layout is final now; correct anything Flutter pulled too early.
        promoTile.sendVisibility(promoState().visible, force: true)
        reportVisibility(force: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        productHeader.sendVisibility(false)
        reviewsPanel.sendVisibility(false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Review Details fills the viewport below the pinned segmented
        // control, so the page's content ends where the panel ends.
        let height = max(
            scrollView.bounds.height - Self.pinnedGap - segment.bounds.height - Self.segmentSpacing,
            200
        )
        if let reviewsHeight, abs(reviewsHeight.constant - height) > 0.5 {
            reviewsHeight.constant = height
        }
    }

    // MARK: - Layout

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.touchOwners = [productHeader, promoTile, reviewsPanel]
        // Pinned to the safe area, so content never slides under the bars:
        // the Flutter tile's safe-area insets stay zero while scrolling, and
        // its viewport metrics never change mid-scroll.
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 22
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: Self.stackBottomMargin, trailing: 16)
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
        addChild(productHeader)
        let hero = makeHero()
        stack.addArrangedSubview(hero)
        productHeader.didMove(toParent: self)

        segment.selectedSegmentIndex = 0
        segment.accessibilityIdentifier = "shopSegment"
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        stack.addArrangedSubview(segment)
        stack.setCustomSpacing(Self.segmentSpacing, after: hero)
        stack.setCustomSpacing(Self.segmentSpacing, after: segment)

        overviewStack.axis = .vertical
        overviewStack.spacing = stack.spacing
        stack.addArrangedSubview(overviewStack)
        buildOverview(in: overviewStack)

        addChild(reviewsPanel)
        reviewsPanel.view.isHidden = true
        reviewsPanel.view.accessibilityIdentifier = "reviewsPanel"
        stack.addArrangedSubview(reviewsPanel.view)
        let reviewsHeight = reviewsPanel.view.heightAnchor.constraint(equalToConstant: 600)
        reviewsHeight.isActive = true
        self.reviewsHeight = reviewsHeight
        reviewsPanel.didMove(toParent: self)
    }

    /// The Overview tab: the native page as it was, promo tile included.
    private func buildOverview(in stack: UIStackView) {
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
        let visible = !overviewStack.isHidden
            && viewport.insetBy(dx: 0, dy: -Self.visibilityMargin).intersects(tile)
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
        reportVisibility()
    }

    /// The 3D header renders only while some of it is on screen, and the
    /// reviews only while their tab is selected and on screen.
    private func reportVisibility(force: Bool = false) {
        let viewport = scrollView.bounds
        func onScreen(_ view: UIView) -> Bool {
            !view.isHidden && viewport.intersects(view.convert(view.bounds, to: scrollView))
        }
        let shown = viewIfLoaded?.window != nil
        productHeader.sendVisibility(shown && onScreen(productHeader.view), force: force)
        reviewsPanel.sendVisibility(shown && onScreen(reviewsPanel.view), force: force)
    }

    // MARK: - Overview | Review Details

    @objc private func segmentChanged() {
        let reviews = segment.selectedSegmentIndex == 1
        overviewStack.isHidden = reviews
        reviewsPanel.view.isHidden = !reviews
        // The panel reaches the bottom of the viewport, so it needs no margin.
        stack.directionalLayoutMargins.bottom = reviews ? 0 : Self.stackBottomMargin
        view.layoutIfNeeded()

        if reviews {
            // Pin the segmented control to the top: the page can scroll no
            // further, and from here on the list inside the panel scrolls.
            let pinned = segment.frame.minY - Self.pinnedGap
            let maxOffset = max(scrollView.contentSize.height - scrollView.bounds.height, 0)
            scrollView.setContentOffset(CGPoint(x: 0, y: min(pinned, maxOffset)), animated: true)
        }
        UISelectionFeedbackGenerator().selectionChanged()
        PerformanceHUDView.shared.setActiveFlutterRoute(route)
        reportScroll()
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
        // The artwork is the `/product` Flutter view: drag it to orbit.
        let artwork = productHeader.view!
        artwork.accessibilityIdentifier = "productHeader"
        artwork.accessibilityLabel = "Nimbus One in 3D. Drag to rotate."
        artwork.heightAnchor.constraint(equalToConstant: Self.headerHeight).isActive = true

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

        let hero = UIStackView(arrangedSubviews: [artwork, details])
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

/// A Flutter view inside the page that may claim drags from its scroll view.
protocol FlutterTouchOwner: AnyObject {
    var view: UIView! { get }

    /// Whether a touch that started at `point`, in the owner's view
    /// coordinates, belongs to Flutter rather than to the page's scroll.
    func ownsTouch(startingAt point: CGPoint) -> Bool
}

extension InlineFlutterCardViewController: FlutterTouchOwner {}

/// Decides, per touch, whether a drag scrolls the page or belongs to Flutter.
///
/// A drag that starts on a Flutter view's owned area is Flutter's, and the
/// page must not steal it once it moves: the badge on the promo tile, and
/// anywhere on the 3D header or the Review Details panel. Any other drag,
/// including one on the promo tile's empty area, scrolls the page as usual.
final class ProductScrollView: UIScrollView {
    var touchOwners: [FlutterTouchOwner] = []
    private var touchStart: (owner: FlutterTouchOwner, point: CGPoint)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Deliver touches to Flutter at once, so grabbing the badge or the
        // model feels immediate and touchesShouldCancel(in:) decides every drag.
        delaysContentTouches = false
        canCancelContentTouches = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
        touchStart = nil
        if let touch = touches.first,
           let owner = touchOwners.first(where: { view.isDescendant(of: $0.view) }) {
            touchStart = (owner, touch.location(in: owner.view))
        }
        return super.touchesShouldBegin(touches, with: event, in: view)
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        if let start = touchStart, view.isDescendant(of: start.owner.view),
           start.owner.ownsTouch(startingAt: start.point) {
            return false
        }
        return super.touchesShouldCancel(in: view)
    }
}
