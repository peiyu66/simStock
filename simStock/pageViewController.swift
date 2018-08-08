//
//  pageViewController.swift
//  simStock
//
//  Created by peiyu on 2017/12/10.
//  Copyright © 2017年 unlock.com.tw. All rights reserved.
//

import UIKit

class pageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    lazy var masterView:masterViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "masterViewController") as! masterViewController
//    lazy var v2:masterViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "masterViewController") as! masterViewController


    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
//        masterView.shiftLeft(withShowPrice: true)
        return masterView

    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
//        masterView.shiftRight(withShowPrice: true)
        return masterView
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = self
        delegate   = self





    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setViewControllers([masterView], direction: .forward, animated: true, completion: nil)
//        for view in self.view.subviews {
//            if let scrollView = view as? UIScrollView {
//                scrollView.delegate = self
//            }
//        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//
//        let subViews:[UIView] = view.subviews
//        var scrollView: UIScrollView? = nil
//        var pageControl: UIPageControl? = nil
//
//        for view in subViews {
//            if view.isKind(of: UIScrollView.self)  {
//                scrollView = view as? UIScrollView
//            }
//            else if view.isKind(of: UIPageControl.self) {
//                pageControl = view as? UIPageControl
//            }
//        }
//
//        if (scrollView != nil && pageControl != nil) {
//            scrollView?.frame = view.bounds
//            view.bringSubview(toFront: pageControl!)
//        }
//    }

//    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
//        if completed {
//            guard let viewController = pageViewController.viewControllers?.first,
//                index = viewControllerDatasource.indexOf(viewController) else {
//                    fatalError("Can't prevent bounce if there's not an index")
//            }
//            currentIndex = index
//        }
//    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        if currentIndex == 0 && scrollView.contentOffset.x < scrollView.bounds.size.width {
//            scrollView.contentOffset = CGPoint(x: scrollView.bounds.size.width, y: 0)
//        } else if currentIndex == totalViewControllers - 1 && scrollView.contentOffset.x > scrollView.bounds.size.width {
//            scrollView.contentOffset = CGPoint(x: scrollView.bounds.size.width, y: 0)
//        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
//        if currentIndex == 0 && scrollView.contentOffset.x < scrollView.bounds.size.width {
//            scrollView.contentOffset = CGPoint(x: scrollView.bounds.size.width, y: 0)
//        } else if currentIndex == totalViewControllers - 1 && scrollView.contentOffset.x > scrollView.bounds.size.width {
//            scrollView.contentOffset = CGPoint(x: scrollView.bounds.size.width, y: 0)
//        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
