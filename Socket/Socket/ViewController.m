//
//  ViewController.m
//  Socket
//
//  Created by CoderZYWang on 2017/3/1.
//  Copyright © 2017年 CoderZYWang_mac. All rights reserved.
//

/**
 客户端 socket 网络请求流程
 （1）客户端调用 socket(...) 创建socket；
 （2）客户端调用 connect(...) 向服务器发起连接请求以建立连接；
 （3）客户端与服务器建立连接之后，就可以通过 send(...)/receive(...) 向客户端发送或从客户端接收数据；
 （4）客户端调用 close 关闭 socket；
 */

#import "ViewController.h"

#import <arpa/inet.h> // 提供IP地址转换函数
#import <netdb.h> // 提供设置及获取域名的函数

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // 创建线程
    [self createThread];
}

/** 创建线程 */
- (void)createThread {
    // connect/recv/send 等接口都是阻塞式的，因此我们需要将这些操作放在非 UI 线程中进行
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self loadDataWithUrl:[NSURL URLWithString:@"telnet://towel.blinkenlights.nl:23"]];
        // 默认端口号 http 80  http 443
    });
}

/** 请求数据 */
- (void)loadDataWithUrl:(NSURL *)url {
    NSString *host = [url host]; // 获取 url 主机地址
    NSNumber *port = [url port]; // 获取 url 端口号
    
//    int socket = socket(AF_INET6, SOCK_STREAM, 0); 不可以用 socket 命名，关键字会报错
    // socket 的创建与初始化，返回该 socket 文件的描述符，如果为 -1 则表示该 socket 创建失败
    int socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0); // 该函数基于 #import <arpa/inet.h>
    
    if (socketFileDescriptor == -1) {
        NSLog(@"socket 创建失败");
        return;
    }
    
    // 从主机获取 IP 地址相关信息
    struct hostent *remoteHostEnt = gethostbyname([host UTF8String]);
    
    if (remoteHostEnt == NULL) {
        close(socketFileDescriptor);
        NSLog(@"无法解析仓库服务器的主机名");
        return;
    }
    
    // 从主机地址结构体中获取服务器地址列表（h_addr_list 是 hostent 结构体中的参数）
    struct in_addr *remoteInAddr = (struct in_addr *)remoteHostEnt -> h_addr_list[0];
    
    // 设置套接字参数
    struct sockaddr_in socketParameters;
    socketParameters.sin_family = AF_INET6; // sin_family指代协议族，在 socket 编程中只能是 AF_INET
    socketParameters.sin_addr = *remoteInAddr; // h_addr_list[0] 属于二级指针。sin_addr 存储IP地址，使用in_addr这个数据结构
    socketParameters.sin_port = htons([port intValue]); //  sin_port 存储端口号（使用网络字节顺序）
    
    // 客户端向特定网络地址的服务器发送连接请求，连接成功返回 0，失败返回 -1。
    // 当服务器建立好之后，客户端通过调用该接口向服务器发起建立连接请求。对于 UDP 来说，该接口是可选的，如果调用了该接口，表明设置了该 UDP socket 默认的网络地址。对 TCP socket来说这就是传说中三次握手建立连接发生的地方。
    // 注意：该接口调用会阻塞当前线程，直到服务器返回
    // connect(<#int#> 未连接的 socket, <#const struct sockaddr *#> socket 参数指针, <#socklen_t#> socket 参数长度)
    int ret = connect(socketFileDescriptor, (struct sockaddr *)&socketParameters, sizeof(socketParameters));
    if (ret == -1) {
        close(socketFileDescriptor);
        NSLog(@"socket 连接失败");
        return;
    }
    
    // 如果程序走到这里，说明 socket 已经成功连接到服务器
    
    // 持续从服务器获取数据，直到数据的结尾
    NSMutableData *dataM = [NSMutableData data];
    
    int maxCount = 6; // 遍历次数 (test)
    int i = 0;
    BOOL isNeedWaitReading = YES; // 是否需要继续读取数据
    while (isNeedWaitReading && i < maxCount) {
        const char *buffer[1024];
        int length = sizeof(buffer);
        
        // recv(<#int#> 接收端套接字描述符 其实就是 socket, <#void *#> 用来存放recv函数接收到的数据的缓冲区, <#size_t#> 指明buff的长度, <#int#> 一般为0)
        // 注意 recv 函数仅仅是 copy 数据，真正的接收数据是协议来完成的
        
        // 从套接字读取缓冲区的数据量，返回读取的字节数
        long result = recv(socketFileDescriptor, &buffer, length, 0);
        
        if (result > 0) {
            [dataM appendBytes:buffer length:result];
        } else { // 如果没有获得任何数据，就停止遍历
            isNeedWaitReading = NO;
        }
        ++ i;
    }
    
//    const char * buffer[1024];
//    int length = sizeof(buffer);
//    long result = recv(socketFileDescriptor, &buffer, length, 0);
//    [dataM appendBytes:buffer length:result];

    close(socketFileDescriptor);
    
    [self showData:dataM];
}

- (void)showData:(NSData *)data {
    // 主线程拿到数据进行展示
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"data --- %@", data);
        
        NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//        NSString *dataStr = [NSString stringdata];
        NSLog(@"dataStr --- %@", dataStr);
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
