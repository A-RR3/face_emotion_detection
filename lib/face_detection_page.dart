import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'home/controller/home_controller.dart';

class FaceDetectionPage extends StatelessWidget {
  // @override

  FaceDetectionPage({super.key}) : _homeController = Get.put(HomeController());
  final HomeController _homeController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(''),
          centerTitle: true,
        ),
        body: GetBuilder<HomeController>(
          init: _homeController,
          // initState: (_) async {
          //   await widget._homeController.loadCamera();
          //   await widget._homeController.startImageStream();
          // },
          builder: (HomeController controller) {
            return (controller.cameraController == null ||
                    !controller.cameraController!.value.isInitialized)
                ? const Center(child: CircularProgressIndicator())
                : controller.imageData == null
                    ? SizedBox.expand(
                        child: Stack(
                          children: [
                            GestureDetector(
                                onScaleStart: controller.handleScaleStart,
                                onScaleUpdate: controller.handleScaleUpdate,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: CameraPreview(
                                      controller.cameraController!),
                                )),
                            Positioned(
                              top: 10,
                              child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: controller.previousPerc,
                                      end: controller.happinessPercentage,
                                    ),
                                    duration: const Duration(milliseconds: 200),
                                    builder: (context, value, child) =>
                                        LinearPercentIndicator(
                                      barRadius: const Radius.circular(10),
                                      width: MediaQuery.of(context).size.width /
                                          1.3,
                                      animation: true,
                                      lineHeight: 20.0,
                                      leading: const Icon(
                                        Icons.sentiment_dissatisfied_outlined,
                                        color: Colors.red,
                                      ),
                                      trailing: const Icon(
                                        Icons.mood,
                                        color: Colors.green,
                                      ),
                                      percent: value,
                                      center: const Text(
                                          ""), //${happinessPercentage * 100}%
                                      linearStrokeCap: LinearStrokeCap.round,
                                      animateFromLastPercent: true,
                                      clipLinearGradient: true,
                                      linearGradient: const LinearGradient(colors: [
                                        Colors.red,
                                        Colors.orange,
                                        Colors.yellowAccent,
                                        Colors.green
                                      ]),
                                      onAnimationEnd: () {
                                        controller.previousPerc =
                                            controller.happinessPercentage;
                                      },
                                    ),
                                  )),
                            ),
                            Positioned(
                              bottom: 30,
                              left: 30,
                              child: Column(
                                children: [
                                  Text(
                                      'Zoom: ${controller.currentZoomLevel.toStringAsFixed(1)}x'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox.expand(
                        child: Image.memory(controller.imageData!));
          },
        ));
  }
}
