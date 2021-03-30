package com.alipay.jdwp.demo.web;

import org.springframework.stereotype.Controller;
import org.springframework.ui.ModelMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

/**
 * Velocity 示例
 * @author huzijie
 */
@Controller
@RequestMapping("/velocity")
public class VelocitySampleController {

    @GetMapping
    public String velocity(ModelMap model) {
        model.addAttribute("message", "Hello, SOFA Stack");
        return "velocity-sample";
    }
}
