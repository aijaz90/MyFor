
import UIKit

let SCREEN_WIDTH = UIScreen.main.bounds.size.width
let SCREEN_HEIGHT = UIScreen.main.bounds.size.height

class MTProgressHud {
    
    static let sharedInstance = MTProgressHud()
    
    var container = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_WIDTH, height: SCREEN_HEIGHT))
    var subContainer = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_WIDTH / 2.0, height: SCREEN_WIDTH / 3.0))
    
    var stackView = UIStackView()
    
    var textLabel = UILabel()
    var activityIndicatorView = UIActivityIndicatorView()
    var blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    init() {
        //Main Container
        container.backgroundColor = UIColor.clear
        container.center = CGPoint(x: SCREEN_WIDTH/2.0, y: SCREEN_HEIGHT/2.0)
        
        //Sub Container
        subContainer.layer.cornerRadius = 5.0
        subContainer.layer.masksToBounds = true
        subContainer.backgroundColor = UIColor.clear
        
        // StackView
        stackView.layer.cornerRadius = 5.0
        stackView.layer.masksToBounds = true
        stackView.backgroundColor = UIColor.clear
        
        //Activity Indicator
        activityIndicatorView.hidesWhenStopped = true
        
        //Text Label
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 0
        textLabel.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        textLabel.textColor = UIColor.darkGray
        
        //Blur Effect
        //always fill the view
        blurEffectView.frame = container.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    
/* Not using, need to update for future use case
    func show() -> Void {
        
        container.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        activityIndicatorView.style = UIActivityIndicatorView.Style.large
        activityIndicatorView.center = CGPoint(x: SCREEN_WIDTH / 2, y: SCREEN_HEIGHT / 2)
        activityIndicatorView.color = UIColor.white
        
        activityIndicatorView.startAnimating()
        container.addSubview(activityIndicatorView)
       if let window = getKeyWindow() {
            window.addSubview(container)
        }
        container.alpha = 0.0
        UIView.animate(withDuration: 0.25, animations: {
            self.container.alpha = 1.0
        })
    }
    
    func showWithBlurView() {
        
        //only apply the blur if the user hasn't disabled transparency effects
        if !UIAccessibility.isReduceTransparencyEnabled {
            container.backgroundColor = UIColor.clear
            container.addSubview(blurEffectView)
        } else {
            container.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        }
        
        activityIndicatorView.style = UIActivityIndicatorView.Style.large
        activityIndicatorView.center = CGPoint(x: SCREEN_WIDTH / 2, y: SCREEN_HEIGHT / 2)
        activityIndicatorView.color = UIColor.white

        activityIndicatorView.startAnimating()
        container.addSubview(activityIndicatorView)
        if let window = getKeyWindow() {
            window.addSubview(container)
        }
        container.alpha = 0.0
        UIView.animate(withDuration: 0.25, animations: {
            self.container.alpha = 1.0
        })
    }
    
    func show(withTitle title: String?) {
        
        container.backgroundColor = UIColor.clear
        
        subContainer.backgroundColor = UIColor.systemGroupedBackground
        subContainer.center = CGPoint(x: SCREEN_WIDTH / 2, y: SCREEN_HEIGHT / 2)
        container.addSubview(subContainer)
        
        activityIndicatorView.style = UIActivityIndicatorView.Style.medium
        activityIndicatorView.color = UIColor.black
        activityIndicatorView.frame = CGRect(x: 0, y: 10, width: subContainer.bounds.width, height: subContainer.bounds.height / 3.0)
        activityIndicatorView.center = CGPoint(x: activityIndicatorView.center.x, y: activityIndicatorView.center.y)
        subContainer.addSubview(activityIndicatorView)
        
        let height: CGFloat = subContainer.bounds.height - activityIndicatorView.bounds.height - 10.0
        textLabel.frame = CGRect(x: 5, y: 10 + activityIndicatorView.bounds.height, width: subContainer.bounds.width - 10.0, height: height - 5.0)
        textLabel.text = title
        subContainer.addSubview(textLabel)
        
        activityIndicatorView.startAnimating()
        if let window = getKeyWindow() {
            window.addSubview(container)
        }
        container.alpha = 0.0
        UIView.animate(withDuration: 0.25, animations: {
            self.container.alpha = 1.0
        })
    }
*/
    
    // Use StackView to manage spinner and text label
    func showDarkBackgroundView(withTitle title: String?) {
        container.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        
        //-1. StackView
        stackView.backgroundColor = UIColor.systemGroupedBackground
        container.addSubview(stackView)
        
        stackView.axis = .vertical
        // The alignment of the arranged subviews perpendicular to the stack view’s axis.
        stackView.alignment = .fill
        stackView.spacing = 8
        // The distribution of the arranged views along the stack view’s axis.
        stackView.distribution = .fillEqually
        
        //-2. Spinner
        activityIndicatorView.style = UIActivityIndicatorView.Style.large
        let spinnerColor = (UIApplication.shared.mainKeyWindow?.rootViewController?.isDarkMode == true) ? UIColor.white : UIColor.black
        activityIndicatorView.color = spinnerColor
        stackView.addArrangedSubview(activityIndicatorView)
        
        //-3. Text Label
        textLabel.text = title
        textLabel.textColor = spinnerColor
        stackView.addArrangedSubview(textLabel)
        
        //-4. Add constraints for the StackView
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.5),
            stackView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.2),
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        activityIndicatorView.startAnimating()
        if let window = getKeyWindow() {
            window.addSubview(container)
            
            //-5. Add constraints for the container view
            container.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                container.topAnchor.constraint(equalTo: window.topAnchor),
                container.bottomAnchor.constraint(equalTo: window.bottomAnchor)
            ])
        }
        
        container.alpha = 0.0
        UIView.animate(withDuration: 0.25, animations: {
            self.container.alpha = 1.0
        })
    }
    
    /* Not using, old code
    func showDarkBackgroundView2(withTitle title: String?) {
        
        container.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        
        subContainer.backgroundColor = UIColor.systemGroupedBackground
        subContainer.center = CGPoint(x: SCREEN_WIDTH / 2, y: SCREEN_HEIGHT / 2)
        container.addSubview(subContainer)
        
        activityIndicatorView.style = UIActivityIndicatorView.Style.medium
        activityIndicatorView.color = UIColor.systemYellow
        activityIndicatorView.frame = CGRect(x: 0,
                                             y: subContainer.bounds.height / 3.0 - 30,  // 10
                                             width: subContainer.bounds.width,
                                             height: subContainer.bounds.height / 3.0)
        activityIndicatorView.center = CGPoint(x: activityIndicatorView.center.x, y: activityIndicatorView.center.y)
        subContainer.addSubview(activityIndicatorView)
        
        let height: CGFloat = subContainer.bounds.height - activityIndicatorView.bounds.height - 10.0
        textLabel.frame = CGRect(x: 5,
                                 y: 10 + activityIndicatorView.bounds.height/2.0,
                                 width: subContainer.bounds.width - 10.0,
                                 height: height - 5.0)
        textLabel.text = title
        subContainer.addSubview(textLabel)
        
        activityIndicatorView.startAnimating()
        if let window = getKeyWindow() {
            window.addSubview(container)
            
            container.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                container.topAnchor.constraint(equalTo: window.topAnchor),
                container.bottomAnchor.constraint(equalTo: window.bottomAnchor)
            ])
        }
        
        container.alpha = 0.0
        UIView.animate(withDuration: 0.25, animations: {
            self.container.alpha = 1.0
        })
    }
    */
    
    /* Not using, need to update for future use case
    func showBlurView(withTitle title: String?) {
        
        //only apply the blur if the user hasn't disabled transparency effects
        if !UIAccessibility.isReduceTransparencyEnabled {
            container.backgroundColor = UIColor.clear
            container.addSubview(blurEffectView)
        } else {
            container.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        }
        
        subContainer.backgroundColor = UIColor.systemGroupedBackground
        activityIndicatorView.color = UIColor.black
        subContainer.center = CGPoint(x: SCREEN_WIDTH / 2, y: SCREEN_HEIGHT / 2)
        container.addSubview(subContainer)
        
        activityIndicatorView.style = UIActivityIndicatorView.Style.medium
        activityIndicatorView.frame = CGRect(x: 0, y: 10, width: subContainer.bounds.width, height: subContainer.bounds.height / 3.0)
        activityIndicatorView.center = CGPoint(x: activityIndicatorView.center.x, y: activityIndicatorView.center.y)
        subContainer.addSubview(activityIndicatorView)
        
        let height: CGFloat = subContainer.bounds.height - activityIndicatorView.bounds.height - 10.0
        textLabel.frame = CGRect(x: 5, y: 10 + activityIndicatorView.bounds.height, width: subContainer.bounds.width - 10.0, height: height - 5.0)
        textLabel.text = title
        subContainer.addSubview(textLabel)
        
        activityIndicatorView.startAnimating()
        if let window = getKeyWindow() {
            window.addSubview(container)
        }
        container.alpha = 0.0
        UIView.animate(withDuration: 0.25, animations: {
            self.container.alpha = 1.0
        })
    }
    */
    
    func updateProgressTitle(_ title: String?) {
        textLabel.text = title
    }
    
    func hide() {
        UIView.animate(withDuration: 0.25, animations: {
            self.container.alpha = 0.0
        }) { finished in
            self.activityIndicatorView.stopAnimating()
            
            self.activityIndicatorView.removeFromSuperview()
            self.textLabel.removeFromSuperview()
            self.subContainer.removeFromSuperview()
            self.blurEffectView.removeFromSuperview()
            self.container.removeFromSuperview()
        }
    }
    
    private func getKeyWindow() -> UIWindow? {
        return UIApplication.shared.mainKeyWindow
        
        /* org code
        let window = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        return window
        */
    }
    
}
