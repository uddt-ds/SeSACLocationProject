//
//  CollectionViewCel.swift
//  SeSACLocationProject
//
//  Created by Lee on 9/10/25.
//

import UIKit

final class CollectionViewCell: UICollectionViewCell {

    static let identifier = "CollectionViewCell"

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configureHierarchy() {
        contentView.addSubview(imageView)
    }

    private func configureLayout() {
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func configureView() {
        contentView.backgroundColor = .white
        backgroundColor = .white
    }
}
