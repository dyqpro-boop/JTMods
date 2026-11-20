//
//  HNCallHistory.swift
//  Runner - Pixel-perfect iOS Call History Detail Simulation
//

import UIKit

@objc(HNFakeCallHistoryViewController)
public class HNFakeCallHistoryViewController: UIViewController {

    public var contactName: String = "+84 35 9145852"
    public var phoneNumber: String = "+84 35 9145852"
    public var callDurationText: String = "20 giây"
    public var callTimeText: String = ""

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    public override func viewDidLoad() {
        super.viewDidLoad()
        if callDurationText == "20 giây", HNURLProtocol.latestFakeCallDuration > 0 {
            callDurationText = "\(HNURLProtocol.latestFakeCallDuration) giây"
        }
        if contactName.isEmpty || contactName.contains("Trần Ngọc Dung") || contactName == "Khách hàng" {
            contactName = formatPhoneDisplay(phoneNumber)
        }
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 190/255.0, green: 192/255.0, blue: 199/255.0, alpha: 1.0)

        if callTimeText.isEmpty {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "h:mm a"
            let timeStr = formatter.string(from: Date())
                .replacingOccurrences(of: "AM", with: "SA")
                .replacingOccurrences(of: "PM", with: "CH")
            callTimeText = timeStr
        }

        // Top Navigation bar
        let topBar = UIView()
        topBar.backgroundColor = UIColor(red: 190/255.0, green: 192/255.0, blue: 199/255.0, alpha: 1.0)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        let backButton = UIButton(type: .system)
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: chevronConfig), for: .normal)
        backButton.tintColor = .systemGray
        backButton.backgroundColor = UIColor(white: 0.8, alpha: 0.5)
        backButton.layer.cornerRadius = 18
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(backButton)

        let editButton = UIButton(type: .system)
        editButton.setTitle("Sửa", for: .normal)
        editButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        editButton.setTitleColor(.systemGray, for: .normal)
        editButton.backgroundColor = UIColor(white: 0.85, alpha: 0.6)
        editButton.layer.cornerRadius = 16
        editButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(editButton)

        // Scroll View
        scrollView.backgroundColor = UIColor(red: 242/255.0, green: 242/255.0, blue: 247/255.0, alpha: 1.0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Bottom Tab Bar
        let tabBar = createFakeTabBar()
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            editButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            editButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: tabBar.topAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 83)
        ])

        buildContentInsideView()
    }

    private func buildContentInsideView() {
        contentView.backgroundColor = UIColor(red: 242/255.0, green: 242/255.0, blue: 247/255.0, alpha: 1.0)

        // Gray contact header background, matching the reference screenshot.
        let profileBackdrop = UIView()
        profileBackdrop.backgroundColor = UIColor(red: 190/255.0, green: 192/255.0, blue: 199/255.0, alpha: 1.0)
        profileBackdrop.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertSubview(profileBackdrop, at: 0)

        // Avatar Circle
        let avatarView = UIView()
        avatarView.backgroundColor = UIColor(red: 164/255.0, green: 169/255.0, blue: 180/255.0, alpha: 1.0)
        avatarView.layer.cornerRadius = 50
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarView)

        let avatarIcon = UIImageView(image: UIImage(systemName: "person.fill"))
        avatarIcon.tintColor = .white
        avatarIcon.contentMode = .scaleAspectFit
        avatarIcon.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarIcon)

        // Contact Name Label
        let nameLabel = UILabel()
        nameLabel.text = contactName
        nameLabel.font = UIFont.systemFont(ofSize: 32, weight: .regular)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        // Action Buttons Row (nhắn tin, gọi, video, gửi thư)
        let actionsStack = UIStackView()
        actionsStack.axis = .horizontal
        actionsStack.distribution = .fillEqually
        actionsStack.spacing = 10
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionsStack)

        actionsStack.addArrangedSubview(createActionButton(icon: "message.fill", title: "nhắn tin", enabled: true))
        actionsStack.addArrangedSubview(createActionButton(icon: "phone.fill", title: "gọi", enabled: true))
        actionsStack.addArrangedSubview(createActionButton(icon: "video.fill", title: "video", enabled: true))
        actionsStack.addArrangedSubview(createActionButton(icon: "envelope.fill", title: "gửi thư", enabled: false))

        // History Card (Hôm nay / Cuộc gọi đi...)
        let historyCard = UIView()
        historyCard.backgroundColor = .white
        historyCard.layer.cornerRadius = 12
        historyCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(historyCard)

        let historyTitle = UILabel()
        historyTitle.text = "Hôm nay"
        historyTitle.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        historyTitle.textColor = .black
        historyTitle.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(historyTitle)

        // Row 1: Cuộc gọi đi (20 giây)
        let call1Title = UILabel()
        call1Title.text = "\(callTimeText)   Cuộc gọi đi"
        call1Title.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        call1Title.textColor = .black
        call1Title.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(call1Title)

        let call1Sub = UILabel()
        call1Sub.text = "        \(callDurationText)"
        call1Sub.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        call1Sub.textColor = .systemGray
        call1Sub.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(call1Sub)

        // Row 2: Cuộc gọi bị hủy
        let call2Title = UILabel()
        call2Title.text = "\(callTimeText)   Cuộc gọi bị hủy"
        call2Title.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        call2Title.textColor = .black
        call2Title.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(call2Title)

        // Row 3: Cuộc gọi bị hủy
        let call3Title = UILabel()
        call3Title.text = "\(callTimeText)   Cuộc gọi bị hủy"
        call3Title.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        call3Title.textColor = .black
        call3Title.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(call3Title)

        // Poster Card
        let posterCard = UIView()
        posterCard.backgroundColor = .white
        posterCard.layer.cornerRadius = 12
        posterCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(posterCard)

        let posterIcon = UIImageView(image: UIImage(systemName: "person.crop.circle"))
        posterIcon.tintColor = .systemGray2
        posterIcon.translatesAutoresizingMaskIntoConstraints = false
        posterCard.addSubview(posterIcon)

        let posterLabel = UILabel()
        posterLabel.text = "Ảnh & áp phích của liên hệ"
        posterLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        posterLabel.textColor = .black
        posterLabel.translatesAutoresizingMaskIntoConstraints = false
        posterCard.addSubview(posterLabel)

        // Phone Card
        let phoneCard = UIView()
        phoneCard.backgroundColor = .white
        phoneCard.layer.cornerRadius = 12
        phoneCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(phoneCard)

        let phoneHeader = UILabel()
        phoneHeader.text = "di động"
        phoneHeader.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        phoneHeader.textColor = .black
        phoneHeader.translatesAutoresizingMaskIntoConstraints = false
        phoneCard.addSubview(phoneHeader)

        let recentBadge = UILabel()
        recentBadge.text = " GẦN ĐÂY "
        recentBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        recentBadge.textColor = .systemGray
        recentBadge.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        recentBadge.layer.cornerRadius = 3
        recentBadge.layer.masksToBounds = true
        recentBadge.translatesAutoresizingMaskIntoConstraints = false
        phoneCard.addSubview(recentBadge)

        let phoneValue = UILabel()
        phoneValue.text = formatPhoneDisplay(phoneNumber)
        phoneValue.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        phoneValue.textColor = .systemBlue
        phoneValue.translatesAutoresizingMaskIntoConstraints = false
        phoneCard.addSubview(phoneValue)

        // Auto Layout Constraints
        NSLayoutConstraint.activate([
            profileBackdrop.topAnchor.constraint(equalTo: contentView.topAnchor),
            profileBackdrop.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            profileBackdrop.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            profileBackdrop.bottomAnchor.constraint(equalTo: actionsStack.bottomAnchor, constant: 20),

            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            avatarView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 100),
            avatarView.heightAnchor.constraint(equalToConstant: 100),

            avatarIcon.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarIcon.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarIcon.widthAnchor.constraint(equalToConstant: 60),
            avatarIcon.heightAnchor.constraint(equalToConstant: 60),

            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            actionsStack.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 20),
            actionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            actionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionsStack.heightAnchor.constraint(equalToConstant: 66),

            historyCard.topAnchor.constraint(equalTo: actionsStack.bottomAnchor, constant: 20),
            historyCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            historyCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            historyTitle.topAnchor.constraint(equalTo: historyCard.topAnchor, constant: 16),
            historyTitle.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 16),

            call1Title.topAnchor.constraint(equalTo: historyTitle.bottomAnchor, constant: 14),
            call1Title.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 16),

            call1Sub.topAnchor.constraint(equalTo: call1Title.bottomAnchor, constant: 2),
            call1Sub.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 16),

            call2Title.topAnchor.constraint(equalTo: call1Sub.bottomAnchor, constant: 14),
            call2Title.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 16),

            call3Title.topAnchor.constraint(equalTo: call2Title.bottomAnchor, constant: 14),
            call3Title.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 16),
            call3Title.bottomAnchor.constraint(equalTo: historyCard.bottomAnchor, constant: -16),

            posterCard.topAnchor.constraint(equalTo: historyCard.bottomAnchor, constant: 16),
            posterCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            posterCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            posterCard.heightAnchor.constraint(equalToConstant: 66),

            posterIcon.leadingAnchor.constraint(equalTo: posterCard.leadingAnchor, constant: 16),
            posterIcon.centerYAnchor.constraint(equalTo: posterCard.centerYAnchor),
            posterIcon.widthAnchor.constraint(equalToConstant: 44),
            posterIcon.heightAnchor.constraint(equalToConstant: 44),

            posterLabel.leadingAnchor.constraint(equalTo: posterIcon.trailingAnchor, constant: 12),
            posterLabel.centerYAnchor.constraint(equalTo: posterCard.centerYAnchor),

            phoneCard.topAnchor.constraint(equalTo: posterCard.bottomAnchor, constant: 16),
            phoneCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            phoneCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            phoneCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            phoneHeader.topAnchor.constraint(equalTo: phoneCard.topAnchor, constant: 12),
            phoneHeader.leadingAnchor.constraint(equalTo: phoneCard.leadingAnchor, constant: 16),

            recentBadge.leadingAnchor.constraint(equalTo: phoneHeader.trailingAnchor, constant: 6),
            recentBadge.centerYAnchor.constraint(equalTo: phoneHeader.centerYAnchor),

            phoneValue.topAnchor.constraint(equalTo: phoneHeader.bottomAnchor, constant: 4),
            phoneValue.leadingAnchor.constraint(equalTo: phoneCard.leadingAnchor, constant: 16),
            phoneValue.bottomAnchor.constraint(equalTo: phoneCard.bottomAnchor, constant: -12)
        ])
    }

    private func createActionButton(icon: String, title: String, enabled: Bool) -> UIView {
        let container = UIView()
        container.backgroundColor = enabled
            ? UIColor(red: 108/255.0, green: 118/255.0, blue: 132/255.0, alpha: 0.65)
            : UIColor(red: 108/255.0, green: 118/255.0, blue: 132/255.0, alpha: 0.3)
        container.layer.cornerRadius = 10

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = enabled ? .white : UIColor(white: 1.0, alpha: 0.35)
        img.contentMode = .scaleAspectFit
        img.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        lbl.textColor = enabled ? .white : UIColor(white: 1.0, alpha: 0.35)

        stack.addArrangedSubview(img)
        stack.addArrangedSubview(lbl)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func createFakeTabBar() -> UIView {
        let tabBar = UIView()
        tabBar.backgroundColor = UIColor(white: 0.96, alpha: 0.95)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(stack)

        stack.addArrangedSubview(createTabItem(icon: "star.fill", title: "Mục ưa thích", selected: false))
        stack.addArrangedSubview(createTabItem(icon: "clock.fill", title: "Gần đây", selected: true))
        stack.addArrangedSubview(createTabItem(icon: "person.crop.circle.fill", title: "Danh bạ", selected: false))
        stack.addArrangedSubview(createTabItem(icon: "circle.grid.3x3.fill", title: "Bàn phím", selected: false))
        stack.addArrangedSubview(createTabItem(icon: "recordingtape", title: "Thư thoại", selected: false))

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tabBar.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: 48)
        ])

        return tabBar
    }

    private func createTabItem(icon: String, title: String, selected: Bool) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2

        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = selected ? .systemBlue : .systemGray
        img.contentMode = .scaleAspectFit
        img.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        lbl.textColor = selected ? .systemBlue : .systemGray

        stack.addArrangedSubview(img)
        stack.addArrangedSubview(lbl)

        return stack
    }

    private func formatPhoneDisplay(_ rawPhone: String) -> String {
        let digits = rawPhone.filter(\.isNumber)
        if digits.hasPrefix("84") {
            let rest = String(digits.dropFirst(2))
            if rest.count == 9 {
                let p1 = rest.prefix(2)
                let p2 = rest.dropFirst(2).prefix(3)
                let p3 = rest.suffix(4)
                return "+84 \(p1) \(p2)\(p3)"
            }
        } else if digits.hasPrefix("0") {
            let rest = String(digits.dropFirst(1))
            if rest.count == 9 {
                let p1 = rest.prefix(2)
                let p2 = rest.dropFirst(2).prefix(3)
                let p3 = rest.suffix(4)
                return "+84 \(p1) \(p2)\(p3)"
            }
        }
        return rawPhone
    }

    @objc private func backButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
}

extension HNFakeCallHistoryViewController {
    /// Render màn hình Call Log Screen ra UIImage
    public static func renderCallHistoryImage(phoneNumber: String, contactName: String? = nil, durationText: String? = nil) -> UIImage {
        let fakeVC = HNFakeCallHistoryViewController()
        let phone = phoneNumber.isEmpty ? "0359145852" : phoneNumber
        fakeVC.phoneNumber = phone
        fakeVC.contactName = contactName ?? phone
        let duration = durationText ?? (HNURLProtocol.latestFakeCallDuration > 0 ? "\(HNURLProtocol.latestFakeCallDuration) giây" : "20 giây")
        fakeVC.callDurationText = duration

        let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
        let bounds = keyWindow?.bounds ?? UIScreen.main.bounds

        fakeVC.view.frame = bounds
        if let keyWindow = keyWindow {
            keyWindow.addSubview(fakeVC.view)
            fakeVC.view.setNeedsLayout()
            fakeVC.view.layoutIfNeeded()
        } else {
            fakeVC.view.setNeedsLayout()
            fakeVC.view.layoutIfNeeded()
        }

        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { ctx in
            fakeVC.view.layer.render(in: ctx.cgContext)
        }

        fakeVC.view.removeFromSuperview()
        return image
    }

    /// Tự động tải/lưu ảnh Call Log Screen vào Bộ sưu tập (Photos)
    public static func downloadAndSaveCallHistoryImage(phoneNumber: String, contactName: String? = nil, durationText: String? = nil, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.main.async {
            let image = renderCallHistoryImage(phoneNumber: phoneNumber, contactName: contactName, durationText: durationText)
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            completion?(true)
        }
    }

    public static func presentInputDialog(from presenter: UIViewController) {
        let workflow = HNCompactWorkflow.shared
        let defaultPhone = workflow.currentPhoneNumber.isEmpty ? "+84 35 9145852" : workflow.currentPhoneNumber
        let alert = UIAlertController(
            title: "MÀN HÌNH NHẬT KÝ CUỘC GỌI",
            message: "Tạo màn hình Nhật ký cuộc gọi iOS giả lập để chụp ảnh báo cáo.",
            preferredStyle: .alert
        )

        alert.addTextField { field in
            field.placeholder = "Số điện thoại / Tên hiển thị"
            field.text = defaultPhone
            field.keyboardType = .phonePad
        }
        alert.addTextField { field in
            field.placeholder = "Thời gian gọi (VD: 20 giây)"
            let latestDuration = HNURLProtocol.latestFakeCallDuration
            field.text = latestDuration > 0 ? "\(latestDuration) giây" : "20 giây"
        }
        alert.addAction(UIAlertAction(title: "Mở Màn Hình", style: .default) { _ in
            let phone = alert.textFields?[0].text ?? defaultPhone
            let duration = alert.textFields?[1].text ?? "20 giây"
            let viewController = HNFakeCallHistoryViewController()
            viewController.phoneNumber = phone.isEmpty ? defaultPhone : phone
            viewController.contactName = viewController.phoneNumber
            viewController.callDurationText = duration.isEmpty ? "20 giây" : duration
            viewController.modalPresentationStyle = .fullScreen
            presenter.present(viewController, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        presenter.present(alert, animated: true)
    }
}
