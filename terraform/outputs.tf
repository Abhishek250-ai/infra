output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.alb.dns_name
}

output "patient_target_group_arn" {
  description = "ARN of the Patient Target Group"
  value       = aws_lb_target_group.patient.arn
}

output "appointment_target_group_arn" {
  description = "ARN of the Appointment Target Group"
  value       = aws_lb_target_group.appointment.arn
}
