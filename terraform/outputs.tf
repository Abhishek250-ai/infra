output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.alb.dns_name
}

output "patient_target_group_arn" {
  value = aws_lb_target_group.patient_tg.arn
}

output "appointment_target_group_arn" {
  value = aws_lb_target_group.appointment_tg.arn
}
