//
//  PhotoViewController.swift
//  SeSACLocationProject
//
//  Created by Lee on 9/10/25.
//

import UIKit
import RxSwift
import RxCocoa
import PhotosUI

final class PhotoViewController: UIViewController {

    var itemProviders: [NSItemProvider] = []
    var iterator: IndexingIterator<[NSItemProvider]>?
    var images: [UIImage] = []
    var imageLoadTrigger = PublishSubject<Void>()

    let disposeBag = DisposeBag()

    var photoDatas = PublishRelay<[UIImage]>()

    private lazy var photoCollectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.makeCollectionViewLayout())
        collectionView.register(CollectionViewCell.self, forCellWithReuseIdentifier: CollectionViewCell.identifier)
        return collectionView
    }()

    private lazy var pickerVC = PHPickerViewController(configuration: self.setupConfig())

    private let button: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .black
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureLayout()
        configureView()
        bind()

        pickerVC.delegate = self
    }

    private func configureHierarchy() {
        [photoCollectionView, button].forEach { view.addSubview($0) }
    }

    private func configureLayout() {
        photoCollectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        button.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.size.equalTo(50)
        }
    }

    private func configureView() {
        view.backgroundColor = .white
    }

    private func makeCollectionViewLayout() -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 0
        layout.itemSize = .init(width: view.frame.width, height: view.frame.width)
        return layout
    }

    private func setupConfig() -> PHPickerConfiguration {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
//        config.preselectedAssetIdentifiers = selected

        return config
    }

    private func bind() {
        button.rx.tap
            .bind(with: self) { owner, _ in
                owner.present(owner.pickerVC, animated: true)
            }
            .disposed(by: disposeBag)

        photoDatas
            .bind(to: photoCollectionView.rx.items(cellIdentifier: CollectionViewCell.identifier, cellType: CollectionViewCell.self)) { (row, element, cell) in
                cell.imageView.image = element
            }
            .disposed(by: disposeBag)
    }

}

extension PhotoViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        print(#function)

        for result in results {
            let itemProvider = result.itemProvider
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image , error in
                    guard let self else { return }
                    self.images.append(image as! UIImage)
                    self.imageLoadTrigger.onNext(())
                }
            }
        }

        imageLoadTrigger
//            .skip(2)
            .bind(with: self) { owner, _ in
                owner.photoDatas.accept(self.images)
            }
            .disposed(by: disposeBag)

        picker.dismiss(animated: true)
    }
}
