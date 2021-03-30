package com.alipay.jdwp.demo.web;

import org.springframework.web.bind.annotation.*;

/**
 * Restful 示例
 */
@RestController
@RequestMapping("/v1/user")
public class JsonSampleController {

    @GetMapping
    public User getUser() {
        return new User("zhangsan", 21);
    }

    @ResponseBody
    @PostMapping
    public void postUser(@RequestBody User user) {
        System.out.println(user.toString());
    }
}
