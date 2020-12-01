import Foundation
import PCA9685
import SingleBoard
import Foundation
import ElementalController
import SwiftyGPIO
  
class MainProcess {

    var pca9685: PCA9685?
  
    var M1_FLT: GPIO?
    var M2_FLT: GPIO?
    
    var M1_PWM: PWMOutput?
    var M2_PWM: PWMOutput?
    
    var M1_SLP: GPIO?
    var M2_SLP: GPIO?
    
    var M1_DIR: GPIO?
    var M2_DIR: GPIO?

     enum MotorDriver {
        case motorHat
        case G2
    }
    
    var useMotorDriver = MotorDriver.G2

    func terminateChildProcess() {

    }

    func main() {

        if useMotorDriver == .motorHat   {
            pca9685 = PCA9685(i2cBus: SingleBoard.raspberryPi.i2cMainBus)
                    
                    // This sets the frequency for all channels
                    // Range: 24 - 1526 Hz
            pca9685!.frequency = 1000 // Hz // ORIGINAL WAS 1440
        } else {
            logDebug("Setting up G2")
            let pwms = SwiftyGPIO.hardwarePWMs(for:.RaspberryPi3)!
            for pwm in pwms {
                print("Got pwm: \(pwm)")
            }
            logDebug("Setting up G2: Initializing PWM")
            M1_PWM = (pwms[0]?[.P12])!
            M2_PWM = (pwms[1]?[.P13])!

            M1_PWM!.initPWM()
            M2_PWM!.initPWM()

            print("PWM status: \(M1_PWM)")

            logDebug("Setting up G2: Initializing GPIO")
            let gpios = SwiftyGPIO.GPIOs(for:.RaspberryPi3)
            M1_FLT = gpios[.P5]!
            M2_FLT = gpios[.P6]!
            
            M1_SLP = gpios[.P22]!
            M2_SLP = gpios[.P23]!
            
            M1_DIR = gpios[.P24]!
            M2_DIR = gpios[.P25]!
            
            M1_FLT!.direction = .IN
            M2_FLT!.direction = .IN
            
            M1_SLP!.direction = .OUT
            M2_SLP!.direction = .OUT
            
            M1_DIR!.direction = .OUT
            M2_DIR!.direction = .OUT
            
            // Bring driver out of sleep
            logDebug("G2: Bringing G2 out of sleep")
            
            M1_SLP!.value = 1
            M2_SLP!.value = 1
        }

        let launchRobotOnboard = Process()
        launchRobotOnboard.launchPath = "/home/robreuss/Development/RPi/RobotOnboard/.build/debug/RobotOnboard"
        launchRobotOnboard.arguments = [""]
        launchRobotOnboard.terminationHandler = { (launchRobotOnboard) in
            print("RobotOnboard terminated: \(!launchRobotOnboard.isRunning) Term Status: \(launchRobotOnboard.terminationStatus)")
            self.brakeAllMotors()
            exit(0)
        }


        // Handle a control-C command on RobotKillswitch by shutting down RobotOnboard
        signal(SIGINT, SIG_IGN) 
        let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigintSrc.setEventHandler {
            print("Got SIGINT, shutting down RobotOnboard")
            print("Finding the PID")
            let pid = launchRobotOnboard.processIdentifier
            let killRobotOnboardCommand = Process()
            killRobotOnboardCommand.launchPath = "kill \(pid)"
            killRobotOnboardCommand.arguments = [""]
            killRobotOnboardCommand.terminationHandler = { (process) in
                print("RobotOnboard terminated.")
                self.brakeAllMotors()
                print("Exiting RobotKillswitch")
                exit(0)
            }
            do {
                print("Launching RobotOnboard...")
                try killRobotOnboardCommand.launch()
            } catch {}
            killRobotOnboardCommand.waitUntilExit()

        }
        sigintSrc.resume()
        do {
            print("Launching RobotOnboard...")
            try launchRobotOnboard.launch()
        } catch {}
        launchRobotOnboard.waitUntilExit()

    }

func brakeAllMotors() {
    if useMotorDriver == .motorHat {
        print("Breaking all motors...")
                self.setPin(pin: 3, value: 0)
                self.setPin(pin: 4, value: 0)
                self.setPin(pin: 5, value: 0)
                self.setPin(pin: 6, value: 0)
                self.setPin(pin: 9, value: 0)
                self.setPin(pin: 10, value: 0)
                self.setPin(pin: 11, value: 0)
                self.setPin(pin: 12, value: 0)
    } else {
        M1_PWM!.startPWM(period: 50000, duty: 0)
        M1_PWM!.startPWM(period: 50000, duty: 0)
    }
}

    func setPin(pin: UInt8, value: UInt8) {
        if (pin < 0) || (pin > 15) {
            logError("Error")
        }
        if (value != 0) && (value != 1) {
            logError("Error")
        }
        
        if (value == 0) {
            self.pca9685!.setChannel(pin, onStep: 0, offStep: 4096)
        }
        if (value == 1) {
            self.pca9685!.setChannel(pin, onStep: 4096, offStep: 0)
        }
    }
}

    var process = MainProcess()
process.main()

while true {
    RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date(timeIntervalSinceNow: 0.1))
}

